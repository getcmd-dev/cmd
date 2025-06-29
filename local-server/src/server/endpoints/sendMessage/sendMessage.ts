import { Request, Response, Router } from "express"
import { logError, logInfo } from "../../../logger"
import { ModelProvider } from "../../providers/provider"
import {
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

export const registerEndpoint = (router: Router, modelProviders: ModelProvider[]) => {
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
			const { fullStream, usage } = await streamText({
				model,
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
			})

			let idx = await processResponseStream(fullStream, res)

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
			logInfo("Request body that led to error:\n\n" + JSON.stringify(req.body, null, 2))
			logError(error)

			throw addUserFacingError(error, "Failed to process message.")
		}
	})
}

/**
 * Processes the response stream received from the provider (and already parsed by Vercel's AI SDK) and convert it to the format expected by the app.
 * @param stream - The resonse stream.
 * @param res - The Express response object to write the streamed response chunks to.
 * @throws {UserFacingError} If an error occurs while processing the stream or sending the response.
 */
async function processResponseStream(
	stream: AsyncIterable<TextStreamPart<Record<string, MappedTool>>>,
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
			res.write(JSON.stringify({ type: "ping", timestamp: Date.now(), idx: i++ } as Ping)) // send a ping to keep the connection alive
		}, 1000)

		for await (const chunk of stream) {
			const transformChunk = (
				chunk: TextStreamPart<Record<string, MappedTool>>,
			): StreamedResponseChunk | undefined => {
				switch (chunk.type) {
					case "text-delta":
						return {
							type: "text_delta",
							text: chunk.textDelta,
							idx: i++,
						}
					case "tool-call-delta":
						return {
							type: "tool_call_delta",
							toolName: chunk.toolName,
							toolUseId: chunk.toolCallId,
							inputDelta: chunk.argsTextDelta,
							idx: i++,
						}
					case "tool-call":
						return {
							type: "tool_call",
							toolName: chunk.toolName,
							toolUseId: chunk.toolCallId,
							input: chunk.args,
							idx: i++,
						}
					case "reasoning":
						return {
							type: "reasoning_delta",
							delta: chunk.textDelta,
							idx: i++,
						}
					case "reasoning-signature":
						return {
							type: "reasoning_signature",
							signature: chunk.signature,
							idx: i++,
						}
					case "error":
						return mapResponseError(chunk.error, () => i++)
					default:
						logInfo(`skipping chunk: ${chunk.type}`)
						return undefined
				}
			}
			const newChunk = transformChunk(chunk)
			if (newChunk === undefined) {
				continue // skip unsupported chunk types
			}
			chunks.push(newChunk)
			if (res.getHeader("Content-Type") === undefined) {
				res.setHeader("Content-Type", "text/event-stream")
				res.setHeader("Cache-Control", "no-cache")
				res.setHeader("Connection", "keep-alive")
			}
			res.write(JSON.stringify(newChunk))
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
		console.log({ error })
		throw addUserFacingError(error, "Failed to send message.")
	}
	return i
}

const debugLogSendingResponseMessageToApp = (chunks: Array<StreamedResponseChunk>) => {
	let messageType:
		| "error"
		| "text_delta"
		| "tool_call"
		| "tool_call_delta"
		| "ping"
		| "reasoning_delta"
		| "reasoning_signature"
		| "usage"
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
		} as CoreSystemMessage
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
		} as CoreUserMessage
	} else if (message.role === "assistant") {
		return {
			role: "assistant",
			content: message.content
				.map((content) => {
					if (isTextMessage(content)) {
						if (content.text.length > 0) {
							return {
								type: "text",
								text: content.text,
							} as TextPart
						} else {
							// skipping messages with empty text
							return undefined
						}
					} else if (isToolUseRequestMessage(content)) {
						return {
							type: "tool-call",
							toolCallId: content.toolUseId,
							toolName: content.toolName,
							args: content.input,
						}
					} else if (isReasoningMessage(content)) {
						return {
							type: "reasoning",
							text: content.text,
							signature: content.signature,
						}
					}
					throw new Error(`Unsupported content type: ${content.type}`)
				})
				.filter(isDefined),
		} as CoreAssistantMessage
	} else if (message.role === "tool") {
		return {
			role: "tool",
			content: message.content.map(asToolResultMessage).map((content) => ({
				type: "tool-result",
				toolCallId: content.toolUseId,
				toolName: content.toolName,
				result: content.result,
			})),
		} as CoreToolMessage
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

const isDefined = <T>(value: T | undefined): value is T => {
	return value !== undefined
}
