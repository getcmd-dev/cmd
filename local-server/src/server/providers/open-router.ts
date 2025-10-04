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
import { notEmpty, notUndefined } from "@/utils/typeChecks"
import { fetchDataRequest } from "./provider-utils"

export type OpenRouterModel = {
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
		max_completion_tokens?: number
	}
	pricing: {
		prompt: string
		completion: string
		image: string
		request: string
		web_search: string
		internal_reasoning: string
		input_cache_read?: string
		input_cache_write?: string
	}
	providers: {
		slug: string
		displayName: string
		baseUrl: string
		iconUrl?: string
		/** Various ways the model can be referred to. Helps get more matches and seems safe */
		slugs: string[]
	}[]
	created: number
	rankForProgramming: number
	supportsReasoning: boolean
}

type OpenRouterModelResponse = {
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
		max_completion_tokens?: number
	}
	pricing: {
		prompt: string
		completion: string
		image: string
		request: string
		web_search: string
		internal_reasoning: string
		input_cache_read?: string
		input_cache_write?: string
	}
	created: number
}

type ModelProviderInfo = {
	provider_model_id: string
	supported_parameters: string[]
	supports_reasoning: boolean
	provider_info: {
		displayName: string
		slug: string
		baseUrl: string
		icon?: {
			url?: string
		}
	}
}
type OpenRouterFindResponse = {
	permaslug: string
	slug: string
	hf_slug?: string
	endpoint?: ModelProviderInfo
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
	async listReferenceModels(): Promise<OpenRouterModel[]> {
		// https://openrouter.ai/docs/api-reference/list-available-models
		const baseUrl = process.env["OPEN_ROUTER_LOCAL_SERVER_PROXY"] ?? "https://openrouter.ai/api/v1"

		// To help with sorting, first fetch models that are popular for programming, then everything else.
		const [programmingModels, allModels, modelsWithProviderInfo] = await Promise.all([
			await fetchDataRequest<OpenRouterModelResponse>(`${baseUrl}/models?category=programming`),
			await fetchDataRequest<OpenRouterModelResponse>(`${baseUrl}/models`),
			await fetchDataRequest<OpenRouterFindResponse>(
				`https://openrouter.ai/api/frontend/models/find`,
				(response) => response.data?.models,
			),
		])
		const programmingRankById = Object.fromEntries(programmingModels.map((model, idx) => [model.id, idx]))
		const rankedModels = allModels.map((model, idx) => ({
			...model,
			rankForProgramming: programmingRankById[model.id] ?? idx + programmingModels.length,
		}))
		const providersInfoByModelSlug: { [modelSlug: string]: OpenRouterFindResponse[] } = {}
		for (const providerInfo of modelsWithProviderInfo) {
			const modelSlug = providerInfo.permaslug
			if (!providersInfoByModelSlug[modelSlug]) {
				providersInfoByModelSlug[modelSlug] = []
			}
			providersInfoByModelSlug[modelSlug].push(providerInfo)
		}

		return rankedModels
			.map((model) => {
				const modelWithProviders = providersInfoByModelSlug[model.canonical_slug]
				if (!modelWithProviders) {
					return undefined
				}
				return {
					...model,
					supportsReasoning: !!modelWithProviders.find((provider) => provider.endpoint?.supports_reasoning),
					providers: modelWithProviders
						.map((modelWithProvider) => {
							if (!modelWithProvider.endpoint) {
								return undefined
							}
							return {
								slug: modelWithProvider.endpoint.provider_info.slug,
								displayName: modelWithProvider.endpoint.provider_info.displayName,
								baseUrl: modelWithProvider.endpoint.provider_info.baseUrl,
								iconUrl: modelWithProvider.endpoint.provider_info.icon?.url,
								slugs: [
									modelWithProvider.endpoint.provider_model_id,
									model.canonical_slug,
									modelWithProvider.slug,
									modelWithProvider.permaslug,
									modelWithProvider.hf_slug,
								].filter(notEmpty),
							}
						})
						.filter(notUndefined),
				}
			})
			.filter(notUndefined)
	}
	async listModels(params: ProviderConfig, referenceModels: OpenRouterModel[]): Promise<ModelRichInfo[]> {
		return referenceModels.map(
			(model): ModelRichInfo => ({
				...model,
				providerId: model.id,
				globalId: model.id,
				max_completion_tokens: model.top_provider.max_completion_tokens,
			}),
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
