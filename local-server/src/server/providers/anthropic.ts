import { ModelProvider, ModelProviderInput, ModelProviderOutput } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { AnthropicProviderOptions, createAnthropic } from "@ai-sdk/anthropic"
import { ModelMessage } from "ai"

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
		}
	}
}

// Anthropic supports ephemeral caching for 4 messages.
// We cache the last content from 'system, the last and penultimate content from 'user'.
export const addCacheControlToMessages = (messages: Array<ModelMessage>, providerName: string): Array<ModelMessage> => {
	// Create a deep copy of messages for the objects of interest to avoid mutating the original value.
	const newMessages = [...messages]
	let systemContentToCache = 1
	let userContentToCache = 2

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
		} else if (message.role === "user" && userContentToCache > 0) {
			if (typeof message.content === "string") {
				throw new Error("Unexpected string content in user message. Should use array of structured content.")
			} else {
				for (let j = message.content.length - 1; j >= 0; j--) {
					if (userContentToCache > 0) {
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
						userContentToCache -= 1
					}
				}
			}
		}
	}
	return newMessages
}
