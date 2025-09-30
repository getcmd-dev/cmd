import {
	ModelModality,
	ModelProvider,
	ModelProviderInput,
	ModelProviderOutput,
	ModelRichInfo,
	ProviderConfig,
} from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createOpenRouter, OpenRouterProviderOptions } from "@openrouter/ai-sdk-provider"
import { addCacheControlToMessages } from "./anthropic"
import { UserFacingError } from "../errors"

export type OpenRoutedModel = {
	id: string
	canonical_slug: string
	name: string
	description: string
	context_length: number
	architecture: {
		input_modalities: ModelModality[]
		output_modalities: ModelModality[]
	}
	top_provider: {
		context_length: number
		max_completion_tokens: number | undefined
	}
	pricing: {
		prompt: string
		completion: string
		image: string
		request: string
		web_search: string
		internal_reasoning: string
		input_cache_read: string | undefined
		input_cache_write: string | undefined
	}
}

export class OpenRouterModelProvider implements ModelProvider {
	name: APIProviderName = "openrouter"
	build(params: ModelProviderInput): ModelProviderOutput {
		const {
			provider: { apiKey, baseUrl },
			modelName,
			reasoningBudget,
		} = params
		const provider = createOpenRouter({
			apiKey: apiKey,
			baseURL: process.env["OPEN_ROUTER_LOCAL_SERVER_PROXY"] ?? baseUrl,
			fetch: modelName.startsWith("anthropic/") ? fetchAnthropicResponse : defaultFetch,
		})

		const providerOptions: OpenRouterProviderOptions = {}
		if (reasoningBudget) {
			providerOptions.reasoning = { max_tokens: reasoningBudget }
		}
		return {
			model: provider(modelName, {
				usage: {
					include: true,
				},
				reasoning: providerOptions.reasoning,
			}),
			addProviderOptionsToMessages: modelName.startsWith("anthropic/")
				? (messages) => addCacheControlToMessages(messages, this.name)
				: undefined,
		}
	}
	async listReferenceModels(): Promise<OpenRoutedModel[]> {
		// https://openrouter.ai/docs/api-reference/list-available-models
		const baseUrl = process.env["OPEN_ROUTER_LOCAL_SERVER_PROXY"] ?? "https://openrouter.ai/api/v1"

		const url = new URL(`${baseUrl}/models`)
		const headers = {}
		const response = await fetch(url.toString(), {
			headers,
		})
		if (!response.ok) {
			throw new UserFacingError({
				message: response.statusText,
				statusCode: response.status,
				underlyingError: new Error(`Failed to fetch models for provider`),
			})
		}
		const data = await response.json()
		return data.data?.map((model: OpenRoutedModel): OpenRoutedModel => model) || []
	}
	async listModels(params: ProviderConfig, referenceModels: OpenRoutedModel[]): Promise<ModelRichInfo[]> {
		// https://openrouter.ai/docs/api-reference/list-available-models
		const baseUrl =
			process.env["OPEN_ROUTER_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "https://openrouter.ai/api/v1"

		const url = new URL(`${baseUrl}/models`)
		const headers = {}
		if (params.apiKey) {
			headers["Authorization"] = `Bearer ${params.apiKey}`
		}
		const response = await fetch(url.toString(), {
			headers,
		})
		if (!response.ok) {
			throw new UserFacingError({
				message: response.statusText,
				statusCode: response.status,
				underlyingError: new Error(`Failed to fetch models for provider`),
			})
		}
		const data = await response.json()
		return (
			data.data?.map(
				(model: OpenRoutedModel): ModelRichInfo => ({
					...model,
					providerId: model.id,
					globalId: model.canonical_slug,
					max_completion_tokens: model.top_provider.max_completion_tokens,
				}),
			) || []
		)
	}
}

const defaultFetch: typeof fetch = (input, init) => {
	if (!init?.body) return fetch(input, init)

	const body = JSON.parse(init.body as string)

	body.stream_options = {
		include_usage: true,
	}
	body.transforms = ["middle-out"]
	body.usage = { include: true }

	init.body = JSON.stringify(body)

	return fetch(input, init)
}

// See https://github.com/OpenRouterTeam/ai-sdk-provider/issues/35#issuecomment-2904161662
const fetchAnthropicResponse: typeof fetch = (input, init) => {
	if (!init?.body) return fetch(input, init)

	const body = JSON.parse(init.body as string)

	body.stream_options = {
		include_usage: true,
	}
	body.transforms = ["middle-out"]

	// Uncomment this to trigger an errror
	// if (body?.messages) {
	// 	for (const message of body.messages) {
	// 		if (typeof message.content === "string") {
	// 			message.content = [
	// 				{
	// 					type: "text",
	// 					text: message.content,
	// 					cache_control: { type: "ephemeral" },
	// 				},
	// 			]
	// 		} else if (Array.isArray(message.content)) {
	// 			for (const item of message.content) {
	// 				if (item && typeof item === "object") {
	// 					item.cache_control = { type: "ephemeral" }
	// 				}
	// 			}
	// 		}
	// 	}
	// }

	if (body?.messages) {
		for (const message of body.messages) {
			if (message.cache_control !== undefined) {
				if (typeof message.content === "string") {
					message.content = [
						{
							type: "text",
							text: message.content,
							cache_control: { type: "ephemeral" },
						},
					]
					delete message.cache_control
				}
			}
		}
	}
	if (body?.tools && body?.tools.length > 0) {
		const lastIdx = body.tools.length - 1
		body.tools[lastIdx] = {
			...body.tools[lastIdx],
			cache_control: { type: "ephemeral" },
		}
	}
	init.body = JSON.stringify(body)

	return fetch(input, init)
}
