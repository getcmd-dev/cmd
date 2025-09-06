import { ModelProvider, ModelProviderInput, ModelProviderOutput } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { AnthropicProviderOptions, createAnthropic } from "@ai-sdk/anthropic"
import { ModelMessage } from "ai"
import { ToolModelWithName } from "../endpoints/sendMessage/sendMessage"

export class AnthropicModelProvider implements ModelProvider {
	name: APIProviderName = "anthropic"
	build(params: ModelProviderInput): ModelProviderOutput {
		const { modelName, apiKey, baseUrl, reasoningBudget } = params
		const provider = createAnthropic({
			apiKey: apiKey,
			baseURL: process.env["ANTHROPIC_LOCAL_SERVER_PROXY"] ?? baseUrl,
		})
		const providerOptions: AnthropicProviderOptions = {}
		if (reasoningBudget) {
			providerOptions.thinking = { type: "enabled", budgetTokens: reasoningBudget }
		}
		return {
			model: provider(modelName),
			generalProviderOptions: {
				anthropic: providerOptions,
			},
			addProviderOptionsToMessages: (messages) => addCacheControlToMessages(messages, this.name),
			addProviderOptionsToTools: (tools) => addCacheControlToTools(tools, this.name),
		}
	}
}

// Anthropic supports ephemeral caching for 4 messages.
// We keep one for tools.
// We cache the last content from 'system, the last and penultimate content from the conversation.
export const addCacheControlToMessages = (messages: Array<ModelMessage>, providerName: string): Array<ModelMessage> => {
	// Create a deep copy of messages for the objects of interest to avoid mutating the original value.
	const newMessages = [...messages]
	let systemContentToCache = 1
	let conversationContentToCache = 2

	for (let i = newMessages.length - 1; i >= 0; i--) {
		const message = newMessages[i]
		if (message.role === "system" && systemContentToCache > 0) {
			newMessages[i] = {
				...message,
				providerOptions: {
					[providerName]: { cacheControl: { type: "ephemeral" } },
				},
			}
			systemContentToCache -= 1
		} else if (message.role === "user" && conversationContentToCache > 0) {
			// The 3 conditions are repeated. Typescript struggles if each message type is not dealt with independently
			if (typeof message.content === "string") {
				throw new Error("Unexpected string content in user message. Should use array of structured content.")
			} else {
				for (let j = message.content.length - 1; j >= 0; j--) {
					if (conversationContentToCache > 0) {
						const newMessage = {
							...message,
							content: [...message.content],
						}
						newMessage.content[j] = {
							...newMessage.content[j],
							providerOptions: {
								[providerName]: { cacheControl: { type: "ephemeral" } },
							},
						}
						newMessages[i] = newMessage
						conversationContentToCache -= 1
					}
				}
			}
		} else if (message.role === "assistant" && conversationContentToCache > 0) {
			if (typeof message.content === "string") {
				throw new Error(
					"Unexpected string content in assistant message. Should use array of structured content.",
				)
			} else {
				for (let j = message.content.length - 1; j >= 0; j--) {
					if (conversationContentToCache > 0) {
						const newMessage = {
							...message,
							content: [...message.content],
						}
						newMessage.content[j] = {
							...newMessage.content[j],
							providerOptions: {
								[providerName]: { cacheControl: { type: "ephemeral" } },
							},
						}
						newMessages[i] = newMessage
						conversationContentToCache -= 1
					}
				}
			}
		} else if (message.role === "tool" && conversationContentToCache > 0) {
			if (typeof message.content === "string") {
				throw new Error("Unexpected string content in tool message. Should use array of structured content.")
			} else {
				for (let j = message.content.length - 1; j >= 0; j--) {
					if (conversationContentToCache > 0) {
						const newMessage = {
							...message,
							content: [...message.content],
						}
						newMessage.content[j] = {
							...newMessage.content[j],
							providerOptions: {
								[providerName]: { cacheControl: { type: "ephemeral" } },
							},
						}
						newMessages[i] = newMessage
						conversationContentToCache -= 1
					}
				}
			}
		}
	}
	return newMessages
}

// Add cache control to the last tool.
export const addCacheControlToTools = (
	tools: Array<ToolModelWithName> | undefined,
	providerName: string,
): Array<ToolModelWithName> | undefined => {
	if (!tools || tools.length === 0) {
		return tools
	}
	// Create a deep copy of tools for the objects of interest to avoid mutating the original value.
	const newTools = [...tools]
	const lastIdx = newTools.length - 1
	newTools[lastIdx] = {
		...newTools[lastIdx],
		providerOptions: {
			[providerName]: { cacheControl: { type: "ephemeral" } },
		},
	}
	return newTools
}
