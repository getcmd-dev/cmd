import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createOpenAI, OpenAIResponsesProviderOptions } from "@ai-sdk/openai"
import { UserFacingError } from "../errors"
import { Model } from "openai/resources/models.mjs"
import { ProviderModelFullInfo } from "./provider"
import { matchModelData } from "./provider-utils"

export class OpenAIAIProvider implements AIProvider {
	name: APIProviderName = "openai"
	build(params: AIProviderInput): AIProviderOutput {
		const {
			provider: { apiKey, baseUrl },
			modelName,
			reasoningBudget,
		} = params
		const provider = createOpenAI({
			apiKey: apiKey,
			baseURL: process.env["OPENAI_LOCAL_SERVER_PROXY"] ?? baseUrl,
			fetch: openAiFetch,
		})
		const providerOptions: OpenAIResponsesProviderOptions = {
			parallelToolCalls: true,
		}

		if (reasoningBudget) {
			providerOptions.reasoningEffort = "medium" // low, medium, and high
		}
		return {
			model: provider(modelName),

			generalProviderOptions: {
				openai: providerOptions,
			},
		}
	}
	async listModels(params: ProviderConfig, referenceModels: ProviderModelFullInfo[]): Promise<ProviderModel[]> {
		const baseUrl = process.env["OPENAI_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "https://api.openai.com"

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
		const allModels = data.data?.map((model: Model): Model => model) || []

		return matchModelData(
			allModels.map((model) => model.id),
			this.name,
			referenceModels,
			(_, idx) => this.identifyModel(allModels[idx], referenceModels),
		)
	}
	identifyModel(model: Model, models: ProviderModelFullInfo[]): ProviderModel | undefined {
		// OpenAI                  ->  OpenRouter
		// gpt-3.5-turbo           ->  openai/gpt-3.5-turbo
		// gpt-3.5-turbo-instruct  ->  openai/gpt-3.5-turbo-instruct
		const matchedId = `openai/${model.id}`
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

const openAiFetch: typeof fetch = (input, init) => {
	if (!init?.body) return fetch(input, init)

	const body = JSON.parse(init.body as string)

	// Remove strict from the schema validation
	body.tools = [
		...body.tools.map((tool) => ({
			...tool,
			function: {
				...tool.function,
				strict: false,
			},
		})),
	]

	init.body = JSON.stringify(body)

	return fetch(input, init)
}
