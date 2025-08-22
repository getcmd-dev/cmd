import { Request, Response, Router } from "express"
import { logError, logInfo, saveLogToFile } from "../../../logger"
import { ModelProvider } from "../../providers/provider"
import {
	InternalContent,
	Message,
	MessageContent,
	Ping,
	ReasoningMessage,
	ResponseUsage,
	SendMessageRequestParams,
	StreamedResponseChunk,
	TextMessage,
	Tool,
	ToolResultMessage,
	ToolUseRequest,
} from "../../schemas/sendMessageSchema"
import { addUserFacingError, UserFacingError } from "../../errors"

import {
	CoreAssistantMessage,
	CoreMessage,
	CoreToolMessage,
	CoreUserMessage,
	streamText,
	Tool as MappedTool,
	jsonSchema,
	TextStreamPart,
	TextPart,
	ImagePart,
	FilePart,
	CoreSystemMessage,
} from "ai"
import { mapResponseError } from "./errorParsing"
import {
	sendMessageToClaudeCode,
	registerEndpoint as registerClaudeCodeEndpoint,
} from "./claudeCode/sendMessageToClaudeCode"

export const registerEndpoint = (router: Router, modelProviders: ModelProvider[], getPort: () => number) => {
	registerClaudeCodeEndpoint(router)
	router.post("/sendMessage", async (req: Request, res: Response) => {
		if (!req.body) {
			throw new UserFacingError({
				message: "Missing body",
				statusCode: 400,
			})
		}
		logInfo("Received request to /sendMessage endpoint")

		try {
			const body = req.body as SendMessageRequestParams
			let messages = body.messages
			const system = body.system
			messages = [
				{
					role: "system",
					content: [
						{
							type: "text",
							text: system,
						},
					],
				} as Message,
				...messages.filter((message) => message.content.length > 0),
			]

			const tools = body.tools

			if (body.provider.name == "claude_code") {
				const threadId = body.threadId
				if (!threadId) {
					throw new UserFacingError({
						message: "Thread ID is required for Claude Code provider.",
					})
				}
				// Claude Code is treated as a special case.
				const localExecutable = body.provider.settings.localExecutable
				if (!localExecutable) {
					throw new UserFacingError({
						message: "Local executable is required for Claude Code provider.",
					})
				}
				await sendMessageToClaudeCode({ messages, localExecutable, port: getPort(), threadId, router }, res)
				return
			}

			const modelProvider = modelProviders.find((provider) => provider.name === body.provider.name)
			if (!modelProvider) {
				throw new UserFacingError({
					message: `Unsupported API provider ${body.provider.name}.`,
				})
			}
			const modelName = body.model
			const { model, generalProviderOptions, addProviderOptionsToMessages } = await modelProvider.build({
				...body.provider.settings,
				modelName,
				reasoningBudget: body.enableReasoning ? 12000 : undefined,
			})
			if (!model) {
				throw new UserFacingError({
					message: `Unsupported model: ${modelName} is not supported by ${body.provider.name}.`,
				})
			}

			// Cleanup when disconnected
			const abortController = new AbortController()
			let responseCompletedByServer = false
			res.on("finish", () => {
				responseCompletedByServer = true
			})
			res.on("close", () => {
				if (!responseCompletedByServer) {
					logInfo("Response closed (client disconnected), aborting the request.")
					abortController.abort()
				}
			})
			res.on("error", (err) => {
				logInfo(`Response error: ${err.message}, aborting the request.`)
				abortController.abort()
			})

			const { fullStream, usage } = await streamText({
				model,
				abortSignal: abortController.signal,
				tools: tools?.map(mapTool).reduce(
					(acc, tool) => {
						acc[tool.name] = tool
						return acc
					},
					{} as Record<string, MappedTool>,
				),
				messages: addProviderOptionsToMessages
					? addProviderOptionsToMessages(messages.map(mapMessage))
					: messages.map(mapMessage),
				toolCallStreaming: true,
				providerOptions: generalProviderOptions,
				maxTokens: 8192,
			})

			let idx = await respondUsingResponseStream(mapStream(fullStream), res)

			const usageInfo = await usage
			const usageRes: ResponseUsage = {
				type: "usage",
				inputTokens: usageInfo.promptTokens,
				outputTokens: usageInfo.completionTokens,
				idx: idx++,
			}

			res.write(JSON.stringify(usageRes))
			res.end()
		} catch (error) {
			const logFile = saveLogToFile("failed_send_message.json", JSON.stringify(req.body, null, 2))
			logInfo(`Request body that led to error saved to ${logFile}`)
			logError(error)

			throw addUserFacingError(error, "Failed to process message.")
		}
	})
}

type MappedOmit<T, K extends keyof T> = { [P in keyof T as P extends K ? never : P]: T[P] }

export type ResponseChunkWithoutIndex = MappedOmit<StreamedResponseChunk, "idx">

/**
 * Converts the response stream received from the provider (and already parsed by Vercel's AI SDK) and convert it to the format expected by the app.
 */
async function* mapStream(
	stream: AsyncIterable<TextStreamPart<Record<string, MappedTool>>>,
): AsyncIterable<ResponseChunkWithoutIndex> {
	for await (const chunk of stream) {
		switch (chunk.type) {
			case "text-delta":
				yield {
					type: "text_delta",
					text: chunk.textDelta,
				}
				break
			case "tool-call-delta":
				yield {
					type: "tool_call_delta",
					toolName: chunk.toolName,
					toolUseId: chunk.toolCallId,
					inputDelta: chunk.argsTextDelta,
				}
				break
			case "tool-call":
				yield {
					type: "tool_call",
					toolName: chunk.toolName,
					toolUseId: chunk.toolCallId,
					input: chunk.args,
				}
				break
			case "reasoning":
				yield {
					type: "reasoning_delta",
					delta: chunk.textDelta,
				}
				break
			case "reasoning-signature":
				yield {
					type: "reasoning_signature",
					signature: chunk.signature,
				}
				break
			case "error": {
				const error = mapResponseError(chunk.error, () => 0)
				yield error
				// Throw the error here to stop the stream immediately
				throw new UserFacingError({
					message: error.message,
					statusCode: error.statusCode,
				})
			}
			default:
				logInfo(`skipping chunk: ${chunk.type}`)
				break
		}
	}
}

/**
 * Respond to the request, using the stream of relevant events.
 * Note: this will add the required event index, as well as send ping on a regular interval.
 * @param stream - The stream of events to send to the caller.
 * @param res - The Express response object to write the streamed response chunks to.
 * @throws {UserFacingError} If an error occurs while processing the stream or sending the response.
 */
export async function respondUsingResponseStream(
	stream: AsyncIterable<ResponseChunkWithoutIndex>,
	res: Response,
): Promise<number> {
	let interval: NodeJS.Timeout | undefined
	let i = 0
	try {
		const chunks: Array<StreamedResponseChunk> = []

		interval = setInterval(() => {
			if (res.getHeader("Content-Type") === undefined) {
				res.setHeader("Content-Type", "text/event-stream")
				res.setHeader("Cache-Control", "no-cache")
				res.setHeader("Connection", "keep-alive")
			}
			res.write(JSON.stringify({ type: "ping", timestamp: Date.now(), idx: i++ } as Ping) + "\n") // send a ping to keep the connection alive
		}, 1000)

		for await (const chunk of stream) {
			const chunkWithIdx: StreamedResponseChunk = { ...chunk, idx: i++ }
			chunks.push(chunkWithIdx)
			if (res.getHeader("Content-Type") === undefined) {
				res.setHeader("Content-Type", "text/event-stream")
				res.setHeader("Cache-Control", "no-cache")
				res.setHeader("Connection", "keep-alive")
			}
			res.write(JSON.stringify(chunkWithIdx) + "\n")
		}
		logInfo("Stream ended")
		if (interval) {
			clearInterval(interval)
		}

		if (process.env.NODE_ENV === "development") {
			debugLogSendingResponseMessageToApp(chunks)
		}
	} catch (error) {
		if (interval) {
			clearInterval(interval)
		}
		logError(`Error while processing stream: ${error}`)
		throw addUserFacingError(error, "Failed to send message.")
	}
	return i
}

const debugLogSendingResponseMessageToApp = (chunks: Array<StreamedResponseChunk>) => {
	let messageType:
		| "error"
		| "text_delta"
		| "tool_call"
		| "tool_use_permission_request"
		| "tool_call_delta"
		| "tool_result"
		| "ping"
		| "reasoning_delta"
		| "reasoning_signature"
		| "usage"
		| "internal_content"
		| undefined
	let text: string | undefined

	const logLastObject = () => {
		if (text !== undefined) {
			logInfo(`Received text:\n${text}`)
			text = undefined
		}
	}
	for (const chunk of chunks) {
		if (chunk.type !== messageType) {
			logLastObject()
		}
		messageType = chunk.type
		if (chunk.type === "text_delta") {
			text = text ?? ""
			text += chunk.text
		} else if (chunk.type === "tool_call") {
			logInfo(`Received tool call:\n${JSON.stringify(chunk)}`)
		} else if (chunk.type === "error") {
			logInfo(`Received error:\n${JSON.stringify(chunk)}`)
		}
	}
	logLastObject()
}

/**
 * Maps a Tool to the format expected by the AI SDK.
 */
const mapTool = (tool: Tool): MappedTool & { name: string } => {
	return {
		description: tool.description,
		name: tool.name,
		parameters: jsonSchema(tool.inputSchema),
	}
}

/**
 * Maps a Message to the format expected by the AI SDK.
 */
const mapMessage = (message: Message): CoreMessage => {
	if (message.role === "system") {
		if (message.content.map(asTextMessage).length !== 1) {
			throw new Error(`System message must have exactly one text content part. Got ${message.content.length}`)
		}
		return {
			role: "system",
			content: message.content.map(asTextMessage)[0].text,
		} satisfies CoreSystemMessage
	} else if (message.role === "user") {
		return {
			role: "user",
			content: message.content.map(asTextMessage).flatMap((content) => {
				const result: Array<TextPart | ImagePart | FilePart> = []
				if (content.text.length > 0) {
					result.push({
						type: "text",
						text: content.text,
					})
				}
				content.attachments?.forEach((attachment) => {
					switch (attachment.type) {
						case "image_attachment":
							result.push({
								type: "image",
								image: attachment.url,
								mimeType: attachment.mimeType,
							})
							break
						case "file_attachment":
							result.push({
								type: "text",
								text: `<full_file>
								<path>${attachment.path}</path>
								<content>
								${attachment.content}
								</content>
							</full_file>
							`,
							})
							break
						case "file_selection_attachment":
							result.push({
								type: "text",
								text: `<file_selection>
								<path>${attachment.path}</path>
								<start_line>${attachment.startLine}</start_line>
								<end_line>${attachment.endLine}</end_line>
								<content>
								${attachment.content}
								</content>
							</file_selection>
							`,
							})
							break
						case "build_error_attachment":
							result.push({
								type: "text",
								text: `Build Error ${attachment.filePath}:${attachment.line}:${attachment.column}: ${attachment.message}`,
							})
							break
					}
				})
				return result
			}),
		} satisfies CoreUserMessage
	} else if (message.role === "assistant") {
		return {
			role: "assistant",
			content: message.content
				.map((content) => {
					if (isTextMessage(content)) {
						if (content.text.length > 0) {
							return {
								type: "text" as const,
								text: content.text,
							} satisfies TextPart
						} else {
							// skipping messages with empty text
							return undefined
						}
					} else if (isToolUseRequestMessage(content)) {
						return {
							type: "tool-call" as const,
							toolCallId: content.toolUseId,
							toolName: content.toolName,
							args: content.input,
						}
					} else if (isReasoningMessage(content)) {
						return {
							type: "reasoning" as const,
							text: content.text,
							signature: content.signature,
						}
					} else if (isInternalContent(content)) {
						// do not forward
						return undefined
					}
					throw new Error(`Unsupported content type for assistant message: ${content.type}`)
				})
				.filter(isDefined),
		} satisfies CoreAssistantMessage
	} else if (message.role === "tool") {
		return {
			role: "tool",
			content: message.content.map(asToolResultMessage).map((content) => ({
				type: "tool-result",
				toolCallId: content.toolUseId,
				toolName: content.toolName,
				result: content.result,
			})),
		} satisfies CoreToolMessage
	} else {
		throw new Error(`Unsupported message role: ${message.role}`)
	}
}

const isTextMessage = (message: MessageContent): message is TextMessage => {
	return message.type === "text"
}

const asTextMessage = (message: MessageContent): TextMessage => {
	if (!isTextMessage(message)) {
		throw new Error(`Unexpected message type ${message.type}, expected 'text'`)
	}
	return message
}

const isToolResultMessage = (message: MessageContent): message is ToolResultMessage => {
	return message.type === "tool_result"
}

const asToolResultMessage = (message: MessageContent): ToolResultMessage => {
	if (!isToolResultMessage(message)) {
		throw new Error(`Unexpected message type ${message.type}, expected 'tool_result'`)
	}
	return message
}
const isToolUseRequestMessage = (message: MessageContent): message is ToolUseRequest => {
	return message.type === "tool_call"
}

const isReasoningMessage = (message: MessageContent): message is ReasoningMessage => {
	return message.type === "reasoning"
}

const isInternalContent = (message: MessageContent): message is InternalContent => {
	return message.type === "internal_content"
}

const isDefined = <T>(value: T | undefined): value is T => {
	return value !== undefined
}
