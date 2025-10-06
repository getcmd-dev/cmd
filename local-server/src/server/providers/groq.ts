import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createGroq } from "@ai-sdk/groq"
import { JSONValue, LanguageModel } from "ai"
import { UserFacingError } from "../errors"
import { ProviderModelFullInfo } from "./provider"
import { matchModelData } from "./provider-utils"

type ModelBaseInfo = {
	id: string
	active: boolean | undefined
	context_window: number
	max_completion_tokens: number
}

export class GroqAIProvider implements AIProvider {
	name: APIProviderName = "groq"
	build(params: AIProviderInput): AIProviderOutput {
		const {
			provider: { apiKey, baseUrl },
			modelName,
			reasoningBudget,
		} = params
		const provider = createGroq({
			apiKey: apiKey,
			baseURL: process.env["GROQ_LOCAL_SERVER_PROXY"] ?? baseUrl,
		})
		const providerOptions: Record<string, JSONValue> = {}
		// See https://ai-sdk.dev/providers/ai-sdk-providers/groq#reasoning-models for parameter information
		if (reasoningBudget) {
			providerOptions.reasoningFormat = "parsed"
			providerOptions.reasoningEffort = modelName === "qwen/qwen3-32b" ? "default" : "medium"
		} else {
			providerOptions.reasoningFormat = "hidden"
			providerOptions.reasoningEffort = modelName === "qwen/qwen3-32b" ? "none" : "low"
		}
		return {
			model: provider(modelName) as unknown as LanguageModel,
			generalProviderOptions: {
				groq: providerOptions,
			},
		}
	}
	async listModels(params: ProviderConfig, referenceModels: ProviderModelFullInfo[]): Promise<ProviderModel[]> {
		// https://console.groq.com/docs/api-reference#models-retrieve
		const baseUrl = process.env["GROQ_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "https://api.groq.com/openai/v1"

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
		const allModels =
			data.data?.flatMap((model: ModelBaseInfo): ModelBaseInfo | undefined =>
				model.active != false ? model : undefined,
			) || []
		return matchModelData(
			allModels.map((model) => model.id),
			this.name,
			referenceModels,
			(_, idx) => this.identifyModel(allModels[idx], referenceModels),
		)
	}
	identifyModel(model: ModelBaseInfo, models: ProviderModelFullInfo[]): ProviderModel | undefined {
		// Groq                                       ->  OpenRouter
		// meta-llama/llama-4-scout-17b-16e-instruct  ->  meta-llama/llama-4-scout
		// moonshotai/kimi-k2-instruct                ->  moonshotai/kimi-k2
		// openai/gpt-oss-20b                         ->  openai/gpt-oss-20b
		const match = models.find((m) => model.id.startsWith(m.id))
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
