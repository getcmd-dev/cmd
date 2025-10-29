import { logError, logInfo } from "@/logger"
import {
	LocalExecutable,
	Message,
	Tool,
	ToolResultFailureMessage,
	ToolResultSuccessMessage,
	ToolUsePermissionRequest,
	ToolUseRequest,
} from "@/server/schemas/sendMessageSchema"
import type { ContentBlockParam } from "@anthropic-ai/sdk/resources"
import { Response, Router } from "express"
import {
	SDKAssistantMessage,
	SDKResultMessage,
	SDKUserMessage,
	type SDKMessage,
	query,
	SDKPartialAssistantMessage,
} from "@anthropic-ai/claude-agent-sdk"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "../sendMessage"
import { AsyncStream } from "@/utils/asyncStream"
import { registerMCPServerEndpoints } from "./mcp"
import { ApprovalResult } from "@/server/schemas/toolApprovalSchema"
import { createHash } from "crypto"
import { spawn } from "@/utils/spawn-promise"
import { v4 as uuidv4 } from "uuid"
import { attachmentAsPart } from "../helpers"
import { pendingToolApprovalRequests } from "../pendingToolApprovalRequests"

// Constants
const TOOL_NAME_PREFIX = "claude_code_"

// Create a consistent hash of tool input for matching
function createInputHash(input: unknown): string {
	return createHash("sha256")
		.update(JSON.stringify(input, (_, v) => (v.constructor === Object ? Object.entries(v).sort() : v)))
		.digest("hex")
		.substring(0, 16)
}

// To handle tool use permissions that are received over MCP, we need to keep track of tool use requests.
// This is because we receive the tool use request first, then the permission request over MCP.
// The permission request doesn't contain the tool use id, so we need to look at past tool use requests to
// find the matching one and pull its id that can then be forwarded.
const toolUseRequests = new Map<string, Array<Omit<ToolUseRequest, "idx"> & { timestamp: number; inputHash: string }>>()

type ExtendedSDKMessage = SDKMessage | Omit<ToolUsePermissionRequest, "idx">

export const sendMessageToClaudeCode = async (
	{
		messages,
		threadId,
		localExecutable,
		port,
		router,
		tools,
	}: {
		messages: Message[]
		threadId: string
		localExecutable: LocalExecutable
		port: number
		router: Router
		tools: Tool[]
	},
	res: Response,
) => {
	const eventStream = await createClaudeCodeEventStream(res, {
		messages,
		localExecutable,
		port,
		threadId,
		router,
		tools,
	})
	await respondUsingResponseStream(wrapStreamWithAbortHandling(mapStream(eventStream, threadId, res)), res)
	logInfo("done responsing, terminating request")
	res.end()

	toolUseRequests.delete(threadId)
}

const createClaudeCodeEventStream = async (
	res: Response,
	{
		messages,
		localExecutable,
		port,
		threadId,
		router,
		tools,
	}: {
		messages: Message[]
		localExecutable: LocalExecutable
		port: number
		threadId: string
		router: Router
		tools: Tool[]
	},
): Promise<AsyncStream<ExtendedSDKMessage>> => {
	// Setup response event listeners first
	let responseCompletedByServer = false
	let responseIsTerminated = false
	res.on("finish", () => {
		logInfo("response finished")
		responseCompletedByServer = true
		responseIsTerminated = true
		// We still call abort here, as the server-side termination could come from an error
		// in the event stream, in which case we need to stop the agent.
		abortController.abort()
	})
	const abortController = new AbortController()
	res.on("close", () => {
		logInfo("response close")
		responseIsTerminated = true

		if (!responseCompletedByServer) {
			logInfo("Response closed (client disconnected), killing Claude Code process.")
			abortController.abort()
		}
	})

	// get the id of the session to resume
	const existingSessionId = ((): string | undefined => {
		for (const message of messages) {
			if (message.role === "assistant") {
				for (const content of message.content) {
					if (content.type === "internal_content" && content.value.type === "session_id") {
						return content.value.sessionId as string
					}
				}
			}
		}
		return undefined
	})()
	const sessionId = existingSessionId || uuidv4()
	// get the user messages since the last message sent
	let firstNewUserMessagesIdx = messages.length
	while (firstNewUserMessagesIdx > 0 && messages[firstNewUserMessagesIdx - 1].role === "user") {
		firstNewUserMessagesIdx--
	}
	logInfo(`First new user messages index: ${firstNewUserMessagesIdx} / Total messages: ${messages.length}`)

	// Merge all the user messages into a single message with several content parts
	// as since 2.0 Claude Code responds to each received message before processing the next ones.
	const newUserMessages = messages.slice(firstNewUserMessagesIdx)
	const userMessageContents: ContentBlockParam[] = []

	newUserMessages.forEach((message) => {
		message.content.forEach((content) => {
			if (content.type === "text") {
				userMessageContents.push({
					text: content.text,
					type: "text",
				})
				content.attachments?.forEach((attachment) => {
					const messagePart = attachmentAsPart(attachment)
					if (messagePart.type === "text") {
						userMessageContents.push(messagePart)
					} else if (messagePart.type === "image") {
						// Remove the data URL prefix if present (e.g., "data:image/png;base64,")
						const base64Data = messagePart.url.replace(/^data:image\/\w+;base64,/, "")
						const fileExtension = messagePart.mimeType.split("/").pop()
						const mediaType: "image/jpeg" | "image/png" | "image/gif" | "image/webp" = (() => {
							switch (fileExtension) {
								case "png":
									return "image/png"
								case "jpg":
									return "image/jpeg"
								case "gif":
									return "image/gif"
								case "webp":
									return "image/webp"
								default:
									return "image/png"
							}
						})()
						userMessageContents.push({
							type: "image",
							source: {
								data: base64Data,
								media_type: mediaType,
								type: "base64",
							},
						})
					}
				})
			}
		})
	})
	const userMessage: SDKUserMessage = {
		type: "user",
		message: {
			role: "user",
			content: userMessageContents,
		},
		parent_tool_use_id: null,
		session_id: sessionId,
	}

	// Create a tmp file for the mcp config used to receive permission requests
	const mcpEndpoint = `/mcp/${threadId}`
	const eventStream = new AsyncStream<ExtendedSDKMessage>()

	// writeFileSync(mcpConfigFilePath, JSON.stringify(mcpConfig, null, 2))
	registerMCPServerEndpoints(router, mcpEndpoint, async (toolName, input) => {
		try {
			logInfo(
				`Received MCP tool approval request for tool "${toolName}" with input: ${JSON.stringify(input, null, 2)}`,
			)

			if (!toolName || typeof toolName !== "string") {
				throw new Error("Invalid tool name provided")
			}

			const newToolName = `${TOOL_NAME_PREFIX}${toolName}`
			const threadRequests = toolUseRequests.get(threadId)

			if (!threadRequests || threadRequests.length === 0) {
				throw new Error(`No tool use requests found for thread ${threadId}`)
			}

			const inputHash = createInputHash(input)

			// First, try to find an exact match by tool name and input hash
			let matchingToolCall = threadRequests
				.filter((toolCall) => toolCall.toolName === newToolName && toolCall.inputHash === inputHash)
				.sort((a, b) => b.timestamp - a.timestamp)[0]

			// If no exact match found, fall back to tool name only and log warning
			if (!matchingToolCall) {
				logInfo(
					`No exact input match found for ${newToolName} with input ${JSON.stringify(input)} hash:${inputHash}, falling back to name-only matching`,
				)
				matchingToolCall = threadRequests
					.filter((toolCall) => toolCall.toolName === newToolName)
					.sort((a, b) => b.timestamp - a.timestamp)[0]
			}

			if (!matchingToolCall) {
				throw new Error(`No existing matching tool call found for ${newToolName} in thread ${threadId}`)
			}

			eventStream.yield({
				type: "tool_use_permission_request",
				toolName: newToolName,
				toolUseId: matchingToolCall.toolUseId,
				input: matchingToolCall.input,
			} satisfies Omit<ToolUsePermissionRequest, "idx">)

			const response = await new Promise<ApprovalResult>((resolve) => {
				pendingToolApprovalRequests.set(matchingToolCall.toolUseId, resolve)
			})

			logInfo(`Got tool approval response for ${newToolName}: ${JSON.stringify(response)}`)
			return response
		} catch (err) {
			logError("Failed to handle MCP tool approval request", err)
			throw err
		}
	})

	const { path: pathToClaudeCodeExecutable, args: executableArgs } = await extractExecutableInfo(localExecutable)

	// Try to remove env variable that might lead to CC exiting with status 1
	// See https://github.com/anthropics/claude-code/issues/4619#issuecomment-3217014571
	const env = { ...localExecutable.env }
	delete env.NODE_OPTIONS
	delete env.VSCODE_INSPECTOR_OPTIONS

	let onReceiveResult: () => void = () => {}
	const receivedResult = new Promise<void>((resolve) => {
		onReceiveResult = resolve
	})

	const createQuery = async (resume: string | undefined) => {
		// The user might decide that some tools are not available.
		// We only compare the list of available tools to the list of tools supported by the app.
		// Other tools supported by Claude Code cannot be enabled/disabled by the app and remain available by default.
		const availableTools = tools.filter((tool) => tool.name.startsWith(TOOL_NAME_PREFIX)).map((tool) => tool.name)
		const disallowedTools = [
			"Glob",
			"TodoWrite",
			"WebFetch",
			"WebSearch",
			"Edit",
			"MultiEdit",
			"Write",
			"Bash",
			"LS",
			"Read",
			"Grep",
		].filter((toolName) => !availableTools.includes(`${TOOL_NAME_PREFIX}${toolName}`))
		if (disallowedTools.length) {
			logInfo(`disallowedTools: ${disallowedTools}`)
		}

		// Added to debug why in some cases we lose connection to CC.
		logInfo(`Sending message to CC. Resume? ${resume}. userMessage: ${JSON.stringify(userMessage)}.`)
		return query({
			prompt: arrayToAsyncIterable([userMessage], receivedResult),
			options: {
				mcpServers: {
					command: {
						type: "http",
						url: `http://localhost:${port}${mcpEndpoint}`,
					},
				},
				permissionPromptToolName: "mcp__command__tool_approval",
				pathToClaudeCodeExecutable,
				executableArgs,
				cwd: localExecutable.cwd,
				// Note: if disallowedTools changed mid session, the new parameter is ignored.
				disallowedTools,
				env,
				abortController,
				includePartialMessages: true,
				maxTurns: 100,
				resume,
				stderr: (data: string) => {
					if (data.startsWith("Spawning Claude Code native binary")) {
						return
					}
					logInfo(`Claude Code stderr: '${data}'`)
					if (data.trim().length && data.trim() !== "Error") {
						// TODO: clarify what's going on
						logError(`Claude Code stderr: ${data}`)
					}
				},
			},
		})
	}

	if (responseIsTerminated) {
		// The response has already been cancelled, abort.
		eventStream.done()
		return eventStream
	}

	// Handle the case where Claude Code doesn't have the conversation in its history.
	// This can happen if the user cancelled the first message before Claude Code responded.
	// In this case, we retry without the resume parameter to start a fresh conversation.
	let runningQuery = await createQuery(existingSessionId)

	const queryStream = await (async (): Promise<AsyncIterable<ExtendedSDKMessage>> => {
		try {
			// Consume the first event to check for errors
			const iterator = runningQuery[Symbol.asyncIterator]()
			const firstEvent = await iterator.next()

			if (firstEvent.done) {
				return runningQuery
			}

			// Check if it's an error about session not found
			if (
				isSDKResultMessage(firstEvent.value) &&
				firstEvent.value.is_error &&
				firstEvent.value.subtype === "success" &&
				firstEvent.value.result.includes("No conversation found with session ID")
			) {
				logInfo(
					`Session ${existingSessionId} not found in Claude Code, retrying without resume to start fresh conversation`,
				)
				try {
					await runningQuery.interrupt()
				} catch {
					// Interrupt might fail if the query has already failed. Continue with the fallback query.
				}
				// Start a new query without resume
				runningQuery = await createQuery(undefined)
				return runningQuery
			}

			// Re-create an async iterable that includes the first event we already consumed
			return (async function* (): AsyncIterableIterator<ExtendedSDKMessage> {
				yield firstEvent.value
				for await (const event of iterator) {
					if (event.type == "result") {
						// The input stream needs to be kept open until Claude Code is done working.
						// The bug is reported here https://github.com/anthropics/claude-code/issues/9705
						onReceiveResult()
					}
					yield event
				}
			})()
		} catch (error) {
			if (`${error}`.includes("Claude Code process aborted by user")) {
				// Fine, not an error
				return (async function* (): AsyncIterableIterator<ExtendedSDKMessage> {})()
			} else {
				logError("Error handling query", error)
				throw error
			}
		}
	})()

	eventStream.pipeFrom(queryStream)

	return eventStream
}

/**
 * Wraps a stream to catch and handle Claude Code abort errors gracefully.
 * This prevents abort errors from being logged as errors when the user cancels a request.
 */
async function* wrapStreamWithAbortHandling(
	stream: AsyncIterable<ResponseChunkWithoutIndex>,
): AsyncIterable<ResponseChunkWithoutIndex> {
	try {
		for await (const chunk of stream) {
			yield chunk
		}
	} catch (error) {
		if (`${error}`.includes("Claude Code process aborted by user")) {
			// User aborted the request - this is expected behavior, not an error
			logInfo(`Stream processing aborted by user: ${error}`)
			return
		}
		// Re-throw other errors to be handled by the caller
		throw error
	}
}

async function* mapStream(
	stream: AsyncIterable<ExtendedSDKMessage>,
	threadId: string,
	res: Response,
): AsyncIterable<ResponseChunkWithoutIndex> {
	let hasSentSessionId = false
	const toolNames: { [toolId: string]: string } = {}

	for await (const event of stream) {
		if (isToolUsePermissionRequest(event)) {
			yield event
			continue
		}
		if (!hasSentSessionId) {
			hasSentSessionId = true

			const sessionInfo: SessionIdInfo = {
				type: "session_id",
				sessionId: event.session_id,
			}

			yield {
				type: "internal_content",
				value: sessionInfo,
			}
		}

		if (isSDKPartialAssistantMessage(event)) {
			if (event.event.type === "content_block_delta") {
				if (event.event.delta.type === "text_delta") {
					yield {
						type: "text_delta",
						text: event.event.delta.text,
					}
				} else if (event.event.delta.type === "thinking_delta") {
					yield {
						type: "reasoning_delta",
						delta: event.event.delta.thinking,
					}
				}
			}
		} else if (isSDKAssistantMessage(event)) {
			for (const contentPart of event.message.content) {
				switch (contentPart.type) {
					case "text": {
						break // Already streamed
					}
					case "thinking": {
						break // Already streamed
					}
					case "tool_use": {
						const toolName = `${TOOL_NAME_PREFIX}${contentPart.name}`
						toolNames[contentPart.id] = toolName
						const input = contentPart.input as Record<string, unknown>

						const toolUseResponse = {
							type: "tool_call",
							toolName,
							toolUseId: contentPart.id,
							input,
						} satisfies Omit<ToolUseRequest, "idx">
						yield toolUseResponse

						if (!toolUseRequests.has(threadId)) {
							toolUseRequests.set(threadId, [])
						}
						toolUseRequests.get(threadId)?.push({
							...toolUseResponse,
							timestamp: Date.now(),
							inputHash: createInputHash(input),
						})
						break
					}
					default: {
						// Ignore other content types for now (server_tool_use, web_search_tool_result, etc.)
						logInfo(`Ignoring unsupported content type: ${contentPart.type}`)
						break
					}
				}
			}
		} else if (isSDKUserMessage(event)) {
			for (const contentPart of event.message.content) {
				if (typeof contentPart === "string") {
					continue
				}
				switch (contentPart.type) {
					case "tool_result": {
						const result: ToolResultSuccessMessage | ToolResultFailureMessage = contentPart.is_error
							? {
									type: "tool_result_failure",
									failure: contentPart.content,
								}
							: {
									type: "tool_result_success",
									success: contentPart.content,
								}
						yield {
							type: "tool_result",
							toolUseId: contentPart.tool_use_id,
							toolName: toolNames[contentPart.tool_use_id] || `${TOOL_NAME_PREFIX}tool`,
							result,
						}
						break
					}
					default: {
						// Ignore other content types for now (server_tool_use, web_search_tool_result, etc.)
						logInfo(`Ignoring unsupported content type: ${contentPart.type}`)
						break
					}
				}
			}
		} else if (isSDKResultMessage(event)) {
			if (event.is_error) {
				if (event.subtype === "success") {
					// Special cases
					if (event.result.startsWith("Claude AI usage limit reached|")) {
						try {
							const resetTS = event.result.split("|")[1]
							const resetDate = new Date(Number(resetTS) * 1000)
							const formatOptions: Intl.DateTimeFormatOptions = {
								hour: "numeric",
								minute: "2-digit",
								timeZoneName: "short",
							}
							// In test environment, use fixed timezone for consistency
							if (process.env.JEST_WORKER_ID !== undefined) {
								formatOptions.timeZone = "America/Los_Angeles"
							}
							yield {
								type: "error",
								// Format like `10pm (America/Los_Angeles).`
								message: `Claude AI usage limit reached. Your limit will reset at ${resetDate.toLocaleTimeString(
									process.env.JEST_WORKER_ID !== undefined
										? "en-US"
										: Intl.DateTimeFormat().resolvedOptions().locale,
									formatOptions,
								)}.`,
							}
							break
						} catch (e) {
							console.error(
								"Error parsing Claude AI usage limit error:",
								e,
								Intl.DateTimeFormat().resolvedOptions().timeZone,
							)
							// Do nothing, fallback to generic error
						}
					}
					yield {
						type: "error",
						message: event.result,
					}
				} else {
					yield {
						type: "error",
						message: "Claude Code encountered an error.",
					}
				}
			}
		} else {
			logInfo(`Ignoring non-SDK message: ${JSON.stringify(event)}`)
		}
	}
}

const isSDKAssistantMessage = (message: ExtendedSDKMessage): message is SDKAssistantMessage => {
	return message.type === "assistant"
}
const isSDKPartialAssistantMessage = (message: ExtendedSDKMessage): message is SDKPartialAssistantMessage => {
	return message.type === "stream_event"
}

const isSDKUserMessage = (message: ExtendedSDKMessage): message is SDKUserMessage => {
	return message.type === "user"
}
const isSDKResultMessage = (message: ExtendedSDKMessage): message is SDKResultMessage => {
	return message.type === "result"
}
const isToolUsePermissionRequest = (message: ExtendedSDKMessage): message is Omit<ToolUsePermissionRequest, "idx"> => {
	return message.type === "tool_use_permission_request"
}

type SessionIdInfo = {
	type: "session_id"
	sessionId: string
}

function arrayToAsyncIterable<T>(arr: T[], endStream: Promise<void>): AsyncIterable<T> {
	return {
		async *[Symbol.asyncIterator]() {
			for (const item of arr) {
				yield item
			}
			await endStream
		},
	}
}

/// Extract the executable path and args from the LocalExecutable configuration.
/// `localExecutable.executable` is a string that may contain the executable name or path along with arguments.
// For instance `claude --dangerously-skip-permissions`
const extractExecutableInfo = async (localExecutable: LocalExecutable): Promise<{ path: string; args: string[] }> => {
	const parts = localExecutable.executable.match(/(?:[^\s"]+|"[^"]*")+/g) || []
	const execName = parts[0]?.replace(/(^"|"$)/g, "") // Remove surrounding quotes if any
	const args = parts.slice(1).map((arg) => arg.replace(/(^"|"$)/g, ""))
	if (!execName) {
		throw new Error("Invalid executable path")
	}
	if (execName.startsWith("/")) {
		// absolute path
		return { path: execName, args }
	}
	const execPath = await spawn("which", {
		args: [execName],
		env: localExecutable.env,
		cwd: localExecutable.cwd,
	}).then((r) => r.stdout.trim())
	if (!execPath.length) {
		throw new Error(`Executable ${execName} not found in PATH`)
	}
	return { path: execPath, args }
}
