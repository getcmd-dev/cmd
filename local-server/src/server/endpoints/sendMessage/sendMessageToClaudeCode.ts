import { logError, logInfo } from "@/logger"
import { LocalExecutable, Message, StreamedResponseChunk } from "@/server/schemas/sendMessageSchema"
import { CoreMessage, CoreUserMessage } from "ai"
import { Response } from "express"
import { spawn } from "child_process"
import { SDKAssistantMessage, type SDKMessage } from "@anthropic-ai/claude-code"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "./sendMessage"
import { AsyncStream } from "@/utils/asyncStream"

export const sendMessageToClaudeCode = async (
	messages: CoreMessage[],
	localExecutable: LocalExecutable,
	res: Response,
) => {
	const eventStream = createClaudeCodeEventStream(messages, localExecutable)
	await respondUsingResponseStream(mapStream(eventStream), res)
	res.end()
}

const createClaudeCodeEventStream = (
	messages: CoreMessage[],
	localExecutable: LocalExecutable,
): AsyncStream<SDKMessage> => {
	let firstNewUserMessagesIdx = messages.length
	while (firstNewUserMessagesIdx > 0 && messages[firstNewUserMessagesIdx - 1].role === "user") {
		firstNewUserMessagesIdx--
	}
	logInfo(`First new user messages index: ${firstNewUserMessagesIdx} / Total messages: ${messages.length}`)

	const newUserMessages = messages.slice(firstNewUserMessagesIdx).filter(isCoreUserMessage)
	const newUserMessagesText = newUserMessages
		.map((message) => {
			if (typeof message.content === "string") {
				return message.content
			}
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

	logInfo(`Spawning Claude with executable: ${localExecutable.executable}`)
	logInfo(`New user messages text: "${newUserMessagesText}"`)

	// Use stdin instead of -p flag to avoid hanging
	const args = ["--output-format", "stream-json", "--verbose", "--max-turns", "100"]
	logInfo(`Full command: ${localExecutable.executable} ${args.join(" ")} (with stdin)`)

	const eventStream = new AsyncStream<SDKMessage>()

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
		const payload = JSON.parse(output) as SDKMessage
		eventStream.yield(payload)
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

	return eventStream
}

export const isCoreUserMessage = (message: CoreMessage): message is CoreUserMessage => {
	return message.role === "user"
}

async function* mapStream(stream: AsyncIterable<SDKMessage>): AsyncIterable<ResponseChunkWithoutIndex> {
	let hasSentSessionId = false
	for await (const event of stream) {
		if (!hasSentSessionId) {
			hasSentSessionId = true
			yield {
				type: "internal_content",
				value: {
					type: "session_id",
					sessionId: event.session_id,
				},
			}
		}

		if (isSDKAssistantMessage(event)) {
			for (const contentPart of event.message.content) {
				switch (contentPart.type) {
					case "text": {
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
					// case "tool_use": {
					// 	yield {
					// 		type: "tool_call",
					// 		toolName: contentPart.name,
					// 		toolUseId: contentPart.id,
					// 		input: contentPart.input,
					// 	}
					//     break
					// }
					default: {
						// Ignore other content types for now (server_tool_use, web_search_tool_result, etc.)
						logInfo(`Ignoring unsupported content type: ${contentPart.type}`)
						break
					}
				}
			}
		}
	}
}

const isSDKAssistantMessage = (message: SDKMessage): message is SDKAssistantMessage => {
	return message.type === "assistant"
}
