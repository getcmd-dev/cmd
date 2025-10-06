import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { AnthropicProviderOptions, createAnthropic } from "@ai-sdk/anthropic"
import { ModelMessage } from "ai"
import { ToolModelWithName } from "../endpoints/sendMessage/sendMessage"
import { UserFacingError } from "../errors"
import { ProviderModelFullInfo } from "./provider"
import { matchModelData } from "./provider-utils"

type ModelBaseInfo = {
	id: string
	display_name: string
}

export class AnthropicAIProvider implements AIProvider {
	name: APIProviderName = "anthropic"
	build(params: AIProviderInput): AIProviderOutput {
		const {
			provider: { apiKey, baseUrl },
			modelName,
			reasoningBudget,
		} = params
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
	async listModels(params: ProviderConfig, referenceModels: ProviderModelFullInfo[]): Promise<ProviderModel[]> {
		const baseUrl = process.env["ANTHROPIC_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "https://api.anthropic.com/v1"
		const allModels: ModelBaseInfo[] = []
		let afterId: string | undefined = undefined

		do {
			const url = new URL(`${baseUrl}/models`)
			if (afterId) {
				url.searchParams.set("after_id", afterId)
			}
			const response = await fetch(url.toString(), {
				headers: {
					"x-api-key": params.apiKey || "",
					"anthropic-version": "2023-06-01",
				},
			})
			if (!response.ok) {
				throw new UserFacingError({
					message: response.statusText,
					statusCode: response.status,
					underlyingError: new Error(`Failed to fetch models for provider`),
				})
			}
			const data = await response.json()
			const models: ModelBaseInfo[] = data.data?.map((model: ModelBaseInfo): ModelBaseInfo => model) || []
			allModels.push(...models)

			afterId = data.has_more ? data.last_id : undefined
		} while (afterId)

		return matchModelData(
			allModels.map((model) => model.id),
			this.name,
			referenceModels,
			(_, idx) => this.identifyModel(allModels[idx], referenceModels),
		)
	}
	identifyModel(model: ModelBaseInfo, models: ProviderModelFullInfo[]): ProviderModel | undefined {
		// Anthropic.model.id claude-sonnet-4-5-20250929
		// OpenRoutermodel.id: anthropic/claude-sonnet-4.5
		// OpenRoutermodel.canonical_slug: anthropic/claude-4.5-sonnet-20250929
		const modelIdWithoutDate = model.id.replace(/-[0-9]{8}$/, "")
		const modelWithDotId = modelIdWithoutDate.replace(/([0-9]+)-([0-9]+)/g, "$1.$2")
		const slug = `anthropic/${modelWithDotId}`
		const match = models.find((m) => m.id === slug)
		if (match) {
			return {
				...match,
				providerId: model.id,
				globalId: match.id,
				name: model.display_name || match.name,
				max_completion_tokens: match.top_provider.max_completion_tokens,
			}
		}
		return undefined
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
