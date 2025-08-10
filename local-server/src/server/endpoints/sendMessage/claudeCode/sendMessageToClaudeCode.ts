import { logError, logInfo } from "@/logger"
import {
	LocalExecutable,
	Message,
	ToolResultFailureMessage,
	ToolResultSuccessMessage,
} from "@/server/schemas/sendMessageSchema"
import { CoreMessage, CoreUserMessage } from "ai"
import { Response, Router } from "express"
import { spawn } from "child_process"
import { SDKAssistantMessage, SDKResultMessage, SDKUserMessage, type SDKMessage } from "@anthropic-ai/claude-code"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "../sendMessage"
import { AsyncStream } from "@/utils/asyncStream"
import { writeFileSync } from "fs"
import path from "path"
import { StreamingJsonParser } from "@/utils/streamingJSONParser"
import { registerMCPServerEndpoints } from "./mcp"

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
	await respondUsingResponseStream(mapStream(eventStream), res)
	res.end()
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
): AsyncStream<SDKMessage> => {
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
						return content.text
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
	// const mcpConfigFilePath = path.join(__dirname, "mcp.json")
	const mcpConfigFilePath = path.join("/tmp/command", `mcp-${threadId}.json`)
	writeFileSync(mcpConfigFilePath, JSON.stringify(mcpConfig, null, 2))
	registerMCPServerEndpoints(router, mcpEndpoint, async (toolName, input) => {
		logInfo(
			`Received MCP tool approval request for tool "${toolName}" with input: ${JSON.stringify(input, null, 2)}`,
		)
		// For now, we approve all requests
		return {
			isAllowed: true,
			rejectionMessage: undefined,
		}
	})

	logInfo(`Spawning Claude with executable: ${localExecutable.executable}. MCP config file: ${mcpConfigFilePath}`)
	logInfo(`New user messages text: "${newUserMessagesText}"`)

	// Use stdin instead of -p flag to avoid hanging
	const args = [
		"--output-format",
		"stream-json",
		"--verbose",
		"--max-turns",
		"100",
		"--mcp-config",
		mcpConfigFilePath,
		// "--dangerously-skip-permissions", // For now, the MCP seems to not work and not receive requests.
		"--permission-prompt-tool",
		"mcp__command__tool_approval",
	]
	if (existingSessionId) {
		args.push("--resume", existingSessionId)
	}
	logInfo(`Full command: ${localExecutable.executable} ${args.join(" ")}`)

	const eventStream = new AsyncStream<SDKMessage>()
	const jsonParser = new StreamingJsonParser()

	const child = spawn(localExecutable.executable, args, {
		stdio: ["pipe", "pipe", "pipe"],
		env: localExecutable.env,
		cwd: localExecutable.cwd,
	})

	child.stdout.setEncoding("utf8")
	child.stderr.setEncoding("utf8")

	child.stdout.on("data", (data) => {
		const output = data.toString()
		logInfo(`Received data from Claude: ${output}`)
		const parsedMessages = jsonParser.processChunk(output)
		for (const payload of parsedMessages) {
			eventStream.yield(payload as SDKMessage)
		}
	})

	child.stderr.on("data", (data) => {
		const error = data.toString()
		logError(`Received error from Claude: ${error}`)
		eventStream.error(new Error(error))
	})

	child.on("close", (code) => {
		logInfo(`Claude process exited with code ${code}`)
		if (code !== 0) {
			eventStream.error(new Error(`Claude process exited with code ${code}`))
		}
		eventStream.done()
	})

	// Write to stdin instead of using -p flag, as for some reason this avoids hanging.
	child.stdin.write(newUserMessagesText)
	child.stdin.end()

	res.on("close", () => {
		logInfo("Response closed (client disconnected), killing Claude process.")
		child.kill()
	})

	res.on("error", (err) => {
		logInfo(`Response error: ${err.message}, killing Claude process.`)
		child.kill()
	})

	return eventStream
}

export const isCoreUserMessage = (message: CoreMessage): message is CoreUserMessage => {
	return message.role === "user"
}

async function* mapStream(stream: AsyncIterable<SDKMessage>): AsyncIterable<ResponseChunkWithoutIndex> {
	let hasSentSessionId = false
	const toolNames: { [toolId: string]: string } = {}

	for await (const event of stream) {
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
						const toolName = `claude_code_${contentPart.name}`
						toolNames[contentPart.id] = toolName
						yield {
							type: "tool_call",
							toolName,
							toolUseId: contentPart.id,
							input: contentPart.input as Record<string, unknown>,
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
							toolName: toolNames[contentPart.tool_use_id] || "claude_code_tool",
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

const isSDKAssistantMessage = (message: SDKMessage): message is SDKAssistantMessage => {
	return message.type === "assistant"
}
const isSDKUserMessage = (message: SDKMessage): message is SDKUserMessage => {
	return message.type === "user"
}
const isSDKResultMessage = (message: SDKMessage): message is SDKResultMessage => {
	return message.type === "result"
}

type SessionIdInfo = {
	type: "session_id"
	sessionId: string
}
