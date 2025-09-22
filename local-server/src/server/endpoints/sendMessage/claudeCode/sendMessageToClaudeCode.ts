import { logError, logInfo } from "@/logger"
import {
	LocalExecutable,
	Message,
	ToolResultFailureMessage,
	ToolResultSuccessMessage,
	ToolUsePermissionRequest,
	ToolUseRequest,
} from "@/server/schemas/sendMessageSchema"
import type { ContentBlockParam } from "@anthropic-ai/sdk/resources"
import { ModelMessage, UserModelMessage } from "ai"
import { Request, Response, Router } from "express"
import {
	SDKAssistantMessage,
	SDKResultMessage,
	SDKUserMessage,
	type SDKMessage,
	query,
	SDKPartialAssistantMessage,
} from "@anthropic-ai/claude-code"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "../sendMessage"
import { AsyncStream } from "@/utils/asyncStream"
import { readFile } from "fs/promises"
import { registerMCPServerEndpoints } from "./mcp"
import { ApprovalResult, ApproveToolUseRequestParams } from "@/server/schemas/toolApprovalSchema"
import { createHash } from "crypto"
import { UserFacingError } from "@/server/errors"
import { JSONL } from "@/utils/jsonl"
import { spawn } from "@/utils/spawn-promise"
import { homedir } from "os"
import { sendCommandToHostApp } from "../../interProcessesBridge"
import { v4 as uuidv4 } from "uuid"

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

const pendingToolApprovalRequests = new Map<string, (result: ApprovalResult) => void>()

type ExtendedSDKMessage = SDKMessage | Omit<ToolUsePermissionRequest, "idx">

export const sendMessageToClaudeCode = async (
	{
		messages,
		threadId,
		localExecutable,
		port,
		router,
	}: {
		messages: Message[]
		threadId: string
		localExecutable: LocalExecutable
		port: number
		router: Router
	},
	res: Response,
) => {
	const eventStream = await createClaudeCodeEventStream(res, { messages, localExecutable, port, threadId, router })
	await respondUsingResponseStream(mapStream(eventStream, threadId, res), res)
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
	}: {
		messages: Message[]
		localExecutable: LocalExecutable
		port: number
		threadId: string
		router: Router
	},
): Promise<AsyncStream<ExtendedSDKMessage>> => {
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

	const newUserMessages = messages.slice(firstNewUserMessagesIdx)
	const userMessages: SDKUserMessage[] = []

	newUserMessages.forEach((message) => {
		const content: Array<ContentBlockParam> = message.content.flatMap((content) => {
			const result: ContentBlockParam[] = []
			if (content.type === "text") {
				result.push({
					text: content.text,
					type: "text",
				})
				content.attachments?.forEach((attachment) => {
					if (attachment.type === "file_attachment") {
						result.push({
							text: `<file_attachment>
									<path>${attachment.path}</path>
									<content>${attachment.content}</content>
								</file_attachment>`,

							type: "text",
						})
					} else if (attachment.type === "file_selection_attachment") {
						result.push({
							text: `<file_selection_attachment>
									<path>${attachment.path}</path>
									<selection>${attachment.content}</selection>
									<start_line>${attachment.startLine}</start_line>
									<end_line>${attachment.endLine}</end_line>
								</file_selection_attachment>`,

							type: "text",
						})
					} else if (attachment.type === "image_attachment") {
						// Remove the data URL prefix if present (e.g., "data:image/png;base64,")
						const base64Data = attachment.url.replace(/^data:image\/\w+;base64,/, "")
						const fileExtension = attachment.mimeType.split("/").pop()
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
						result.push({
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
			return result
		})
		userMessages.push({
			type: "user",
			message: {
				role: "user",
				content,
			},
			parent_tool_use_id: null,
			session_id: sessionId,
		})
	})

	// Create a tmp file for the mcp config used to receive permission requests
	const mcpEndpoint = `/mcp/${threadId}`
	const eventStream = new AsyncStream<ExtendedSDKMessage>()

	// writeFileSync(mcpConfigFilePath, JSON.stringify(mcpConfig, null, 2))
	registerMCPServerEndpoints(router, mcpEndpoint, async (toolName, input) => {
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
	})

	const abortController = new AbortController()
	const { path: pathToClaudeCodeExecutable, args: executableArgs } = await extractExecutableInfo(localExecutable)
	const runningQuery = query({
		prompt: arrayToAsyncIterable(userMessages),
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
			env: localExecutable.env,
			abortController,
			includePartialMessages: true,
			maxTurns: 100,
			resume: existingSessionId,
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

	eventStream.pipeFrom(runningQuery)

	let responseCompletedByServer = false
	res.on("finish", () => {
		responseCompletedByServer = true
	})
	res.on("close", () => {
		if (!responseCompletedByServer) {
			logInfo("Response closed (client disconnected), killing Claude Code process.")
			runningQuery.interrupt().catch((err) => {
				logError(`Error interrupting running query: ${err.message}`)
			})
			abortController.abort()
		}
	})

	return eventStream
}

export const isCoreUserMessage = (message: ModelMessage): message is UserModelMessage => {
	return message.role === "user"
}

async function* mapStream(
	stream: AsyncIterable<ExtendedSDKMessage>,
	threadId: string,
	res: Response,
): AsyncIterable<ResponseChunkWithoutIndex> {
	let hasSentSessionId = false
	let hasKickOffConversationNaming = false
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

		if (!hasKickOffConversationNaming) {
			hasKickOffConversationNaming = true
			readConversationSummary(event.session_id, threadId, res).catch((e) => {
				logError(e)
			})
		}
	}
}

/** Read the data written to disk by CC to find a conversation name / summary that can be used to name the conversation in the host app */
export const readConversationSummary = async (sessionId: string, threadId: string, res: Response): Promise<void> => {
	if (process.env.JEST_WORKER_ID !== undefined) {
		// Skipped during tests
		return
	}
	let isCancelled = false
	res.on("close", () => {
		// Give a bit of time for CC to write down the conversation data.
		setTimeout(() => {
			isCancelled = true
		}, 1000)
	})
	while (!isCancelled) {
		try {
			const res = await spawn("find", { args: [`${homedir()}/.claude/projects`, "-name", `${sessionId}.jsonl`] })
			const conversationDataPath = res.stdout.trim()
			if (conversationDataPath.length > 0) {
				const conversationContent = await readFile(conversationDataPath, "utf8")
				const conversationData = JSONL.parse(conversationContent)
				for (const data of conversationData.reverse() as Array<{
					type: string
					summary: string | undefined
				}>) {
					if (data.type === "summary" && data.summary !== undefined) {
						logInfo(`sending conversation name: ${data.summary}`)
						sendCommandToHostApp({
							type: "execute-command",
							command: "set_conversation_name",
							input: {
								name: data.summary,
								threadId,
							},
						})
						return
					}
				}
			}
		} catch {}
		await new Promise((resolve) => setTimeout(resolve, 100))
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

export const registerEndpoint = (router: Router) => {
	// This endpoint is used to receive the result of pending tool permission requests.
	router.post("/sendMessage/toolUse/permission", async (req: Request, res: Response) => {
		const body = req.body as ApproveToolUseRequestParams
		const { toolUseId, approvalResult } = body

		if (!toolUseId || typeof toolUseId !== "string") {
			throw new UserFacingError({
				message: "Invalid toolUseId",
				statusCode: 400,
			})
		}

		if (!approvalResult || !approvalResult.type) {
			throw new UserFacingError({
				message: "Invalid approvalResult",
				statusCode: 400,
			})
		}

		logInfo(`received tool use permission request: ${toolUseId}, ${JSON.stringify(approvalResult)}.`)

		const pendingRequest = pendingToolApprovalRequests.get(toolUseId)
		if (!pendingRequest) {
			throw new UserFacingError({
				message: `No pending tool use approval request found for tool use ${toolUseId}`,
				statusCode: 404,
			})
		}

		// Remove from pending requests and resolve
		pendingToolApprovalRequests.delete(toolUseId)
		pendingRequest(approvalResult)
		res.json({ success: true })
	})
}

function arrayToAsyncIterable<T>(arr: T[]): AsyncIterable<T> {
	return {
		async *[Symbol.asyncIterator]() {
			for (const item of arr) {
				// You can introduce asynchronous operations here if needed,
				// for example, simulating a delay with await new Promise()
				yield item
			}
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
