import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createMistral, MistralLanguageModelOptions } from "@ai-sdk/mistral"
import { UserFacingError } from "../errors"
// import { Model } from "openai/resources/models.mjs"
import { ProviderModelFullInfo } from "./provider"
import { matchModelData } from "./provider-utils"
import { BaseModelCard } from "@mistralai/mistralai/models/components"
import { logInfo } from "@/logger"

export class MistralAIProvider implements AIProvider {
	name: APIProviderName = "mistral"
	build(params: AIProviderInput): AIProviderOutput {
		const {
			provider: { apiKey, baseUrl },
			modelName,
			reasoningBudget,
		} = params
		const provider = createMistral({
			apiKey: apiKey,
			baseURL: process.env["MISTRAL_LOCAL_SERVER_PROXY"] ?? baseUrl,
			// fetch: mistralFetch,
		})
		const providerOptions: MistralLanguageModelOptions = {
			parallelToolCalls: true,
		}
		return {
			model: provider(modelName),

			generalProviderOptions: {
				mistral: providerOptions,
			},
		}
	}
	async listModels(params: ProviderConfig, referenceModels: ProviderModelFullInfo[]): Promise<ProviderModel[]> {
		const baseUrl = process.env["MISTRAL_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "https://api.mistral.ai"

		const headers = {}
		if (params.apiKey) {
			headers["Authorization"] = `Bearer ${params.apiKey}`
		}

		const url = new URL(`${baseUrl}/models`)
		const response = await fetch(url.toString(), {
			headers,
		})
		if (!response.ok) {
			throw new UserFacingError({
				message: `Failed to fetch models: ${response.statusText}}`,
				statusCode: response.status,
			})
		}
		const data = await response.json()
		const allModels = data.data?.map((model: BaseModelCard): BaseModelCard => model) || []
		logInfo(`Available Mistral Models: ${JSON.stringify(allModels, null, 2)}`)
		logInfo(`Available Mistral Models ids: ${allModels.map((model) => model.id)}`)

		return matchModelData(
			allModels.map((model) => model.id),
			this.name,
			referenceModels,
			(_, idx) => this.identifyModel(allModels[idx], referenceModels),
		)
	}
	identifyModel(model: BaseModelCard, models: ProviderModelFullInfo[]): ProviderModel | undefined {
		// Mistral                   ->  OpenRouter
		// magistral-medium-latest   ->  mistralai/magistral-medium-latest
		const matchedId = `mistralai/${model.id}`
		const match = models.find((m) => matchedId == m.id)
		if (match) {
			return {
				...match,
				providerId: model.id,
				globalId: match.id,
				max_completion_tokens: match.top_provider.max_completion_tokens,
			}
		}
		return undefined
	}
}

// const mistralFetch: typeof fetch = (input, init) => {
// 	if (!init?.body) return fetch(input, init)

// 	const body = JSON.parse(init.body as string)

// 	// Remove strict from the schema validation
// 	body.tools = [
// 		...(body.tools ?? []).map((tool) => ({
// 			...tool,
// 			function: {
// 				...tool.function,
// 				strict: false,
// 			},
// 		})),
// 	]

// 	init.body = JSON.stringify(body)

// 	return fetch(input, init)
// }
