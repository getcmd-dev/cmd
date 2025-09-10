import { logError, logInfo } from "@/logger"
import {
	LocalExecutable,
	Message,
	ToolResultFailureMessage,
	ToolResultSuccessMessage,
	ToolUsePermissionRequest,
	ToolUseRequest,
} from "@/server/schemas/sendMessageSchema"
import { ModelMessage, UserModelMessage } from "ai"
import { Request, Response, Router } from "express"
import { spawn as spawnStream } from "child_process"
import { SDKAssistantMessage, SDKResultMessage, SDKUserMessage, type SDKMessage } from "@anthropic-ai/claude-code"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "../sendMessage"
import { AsyncStream } from "@/utils/asyncStream"
import { writeFileSync, existsSync, mkdirSync } from "fs"
import { readFile } from "fs/promises"
import path from "path"
import { StreamingJsonParser } from "@/utils/streamingJSONParser"
import { registerMCPServerEndpoints } from "./mcp"
import { ApprovalResult, ApproveToolUseRequestParams } from "@/server/schemas/toolApprovalSchema"
import { createHash } from "crypto"
import { UserFacingError } from "@/server/errors"
import { JSONL } from "@/utils/jsonl"
import { spawn } from "@/utils/spawn-promise"
import { homedir } from "os"
import { sendCommandToHostApp } from "../../interProcessesBridge"

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
	const eventStream = createClaudeCodeEventStream(res, { messages, localExecutable, port, threadId, router })
	await respondUsingResponseStream(mapStream(eventStream, threadId, res), res)
	logInfo("done responsing, terminating request")
	res.end()

	toolUseRequests.delete(threadId)
}

const createClaudeCodeEventStream = (
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
): AsyncStream<ExtendedSDKMessage> => {
	// get the user messages since the last message sent
	let firstNewUserMessagesIdx = messages.length
	while (firstNewUserMessagesIdx > 0 && messages[firstNewUserMessagesIdx - 1].role === "user") {
		firstNewUserMessagesIdx--
	}
	logInfo(`First new user messages index: ${firstNewUserMessagesIdx} / Total messages: ${messages.length}`)

	const newUserMessages = messages.slice(firstNewUserMessagesIdx)
	const newUserMessagesText = newUserMessages
		.map((message) => {
			return message.content
				.map((content) => {
					if (content.type === "text") {
						let text = content.text
						content.attachments?.forEach((attachment) => {
							if (attachment.type === "file_attachment") {
								text += `
								<file_attachment>
									<path>${attachment.path}</path>
									<content>${attachment.content}</content>
								</file_attachment>`
							} else if (attachment.type === "file_selection_attachment") {
								text += `
								<file_selection_attachment>
									<path>${attachment.path}</path>
									<selection>${attachment.content}</selection>
									<start_line>${attachment.startLine}</start_line>
									<end_line>${attachment.endLine}</end_line>
								</file_selection_attachment>`
							} else if (attachment.type === "image_attachment") {
								let filePath: string
								if (attachment.path) {
									filePath = attachment.path
								} else {
									// No path available. This can happen when the image was copied from the pasteboard.

									// Remove the data URL prefix if present (e.g., "data:image/png;base64,")
									const base64Data = attachment.url.replace(/^data:image\/\w+;base64,/, "")
									const fileExtension = attachment.mimeType.split("/").pop()
									// Write the image to a tmp file
									const imageBuffer = Buffer.from(base64Data, "base64")
									const tmpPath = `/tmp/cmd/${createHash("sha256").update(attachment.url).digest("hex").toString().slice(0, 8)}.${fileExtension}`
									const dir = path.dirname(tmpPath)
									if (!existsSync(dir)) {
										mkdirSync(dir)
									}
									writeFileSync(tmpPath, imageBuffer)
									filePath = tmpPath
								}

								text += `
								<image_attachment>
									<mimeType>${attachment.mimeType}</mimeType>
									<path>${filePath}</path>
								</image_attachment>`
							}
						})
						return text
					}
					return undefined
				})
				.filter(Boolean)
				.join("\n")
		})
		.join("\n")

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

	// Create a tmp file for the mcp config used to receive permission requests
	const mcpEndpoint = `/mcp/${threadId}`
	const mcpConfig = {
		mcpServers: {
			command: {
				type: "http",
				url: `http://localhost:${port}${mcpEndpoint}`,
			},
		},
	}
	const dir = "/tmp/command"
	const mcpConfigFilePath = path.join(dir, `mcp-${threadId}.json`)
	if (!existsSync(dir)) {
		mkdirSync(dir, {
			mode: 0o700,
		})
	}
	const eventStream = new AsyncStream<ExtendedSDKMessage>()

	writeFileSync(mcpConfigFilePath, JSON.stringify(mcpConfig, null, 2))
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

	logInfo(`Spawning Claude with executable: ${localExecutable.executable}. MCP config file: ${mcpConfigFilePath}`)
	logInfo(`New user messages text: "${newUserMessagesText}"`)

	const args = [
		"--output-format",
		"stream-json",
		"--verbose",
		"--max-turns",
		"100",
		"--mcp-config",
		mcpConfigFilePath,
		"--permission-prompt-tool",
		"mcp__command__tool_approval",
	]
	if (existingSessionId) {
		args.push("--resume", existingSessionId)
	}
	logInfo(`Full command: ${localExecutable.executable} ${args.join(" ")} -p "${newUserMessagesText}"`)

	const jsonParser = new StreamingJsonParser()

	const child = spawnStream(localExecutable.executable, args, {
		stdio: ["pipe", "pipe", "pipe"],
		env: localExecutable.env,
		cwd: localExecutable.cwd,
	})

	child.stdout.setEncoding("utf8")
	child.stderr.setEncoding("utf8")

	child.stdout.on("data", (data) => {
		const output = data.toString()
		logInfo(`Received data from Claude Code: ${output}`)
		const parsedMessages = jsonParser.processChunk(output)
		for (const payload of parsedMessages) {
			eventStream.yield(payload as SDKMessage)
		}
	})

	child.stderr.on("data", (data) => {
		const error = data.toString()
		logError(`Received error from Claude Code: ${error}`)
		eventStream.error(new Error(error))
	})

	child.on("close", (code) => {
		logInfo(`Claude Code process exited with code ${code}`)
		if (code !== 0) {
			logError("Claude Code was killed with an external error. Ending stream.")
			eventStream.error(new Error(`Claude Code process exited with code ${code}`))
		}
		eventStream.done()
	})

	// Write to stdin instead of using -p flag, as for some reason this avoids hanging.
	child.stdin.write(newUserMessagesText)
	child.stdin.end()

	let responseCompletedByServer = false
	res.on("finish", () => {
		responseCompletedByServer = true
	})
	res.on("close", () => {
		if (!responseCompletedByServer) {
			logInfo("Response closed (client disconnected), killing Claude Code process.")
			child.kill()
		}
	})

	res.on("error", (err) => {
		logError(`Claude Code will be killed after having error: ${err.message}`)
		eventStream.error(new Error(`Claude Code errored: ${err.message}`))
		eventStream.done()
		child.kill()
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

		if (isSDKAssistantMessage(event)) {
			for (const contentPart of event.message.content) {
				switch (contentPart.type) {
					case "text": {
						// Special cases
						if (contentPart.text.startsWith("Claude AI usage limit reached|")) {
							// ignore, this will also show up as an error
							break
						}
						yield {
							type: "text_delta",
							text: contentPart.text + "\n",
						}
						break
					}
					case "thinking": {
						yield {
							type: "reasoning_delta",
							delta: contentPart.thinking + "\n",
						}
						break
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
			const res = await spawn("find", [`${homedir()}/.claude/projects`, "-name", `${sessionId}.jsonl`])
			const conversationDataPath = res.stdout.trim()
			if (conversationDataPath.length > 0) {
				const conversationContent = await readFile(conversationDataPath, "utf8")

				logInfo(
					`Found conversation data path: ${conversationDataPath}. Has content: ${conversationContent.length > 0}`,
				)
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
