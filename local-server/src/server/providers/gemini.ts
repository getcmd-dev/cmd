import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createGoogleGenerativeAI } from "@ai-sdk/google"
import { JSONValue, LanguageModel } from "ai"
import { UserFacingError } from "../errors"
import { ProviderModelFullInfo } from "./provider"
import { matchModelData } from "./provider-utils"

type ModelBaseInfo = {
	name: string
	displayName: string
	description: string
	inputTokenLimit: number
	outputTokenLimit: number
}

export class GeminiAIProvider implements AIProvider {
	name: APIProviderName = "gemini"
	build(params: AIProviderInput): AIProviderOutput {
		const {
			provider: { apiKey, baseUrl },
			modelName,
			reasoningBudget,
		} = params
		const provider = createGoogleGenerativeAI({
			apiKey: apiKey,
			baseURL: process.env["GEMINI_LOCAL_SERVER_PROXY"] ?? baseUrl,
		})
		const providerOptions: Record<string, JSONValue> = {}
		if (reasoningBudget) {
			providerOptions.thinkingConfig = {
				thinkingBudget: reasoningBudget,
				includeThoughts: true,
			}
		}
		return {
			model: provider(modelName) as unknown as LanguageModel,
			generalProviderOptions: {
				google: providerOptions,
			},
		}
	}
	async listModels(params: ProviderConfig, referenceModels: ProviderModelFullInfo[]): Promise<ProviderModel[]> {
		// https://ai.google.dev/api/models#endpoint_1
		const baseUrl =
			process.env["GEMINI_LOCAL_SERVER_PROXY"] ??
			params.baseUrl ??
			"https://generativelanguage.googleapis.com/v1beta/"
		const allModels: ModelBaseInfo[] = []
		let nextPageToken: string | undefined = undefined

		do {
			const url = new URL(`${baseUrl}/models`)
			if (nextPageToken) {
				url.searchParams.set("pageToken", nextPageToken)
			}
			const headers = {}
			if (params.apiKey) {
				headers["x-goog-api-key"] = params.apiKey
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
			const models: ModelBaseInfo[] = data.models?.map((model: ModelBaseInfo): ModelBaseInfo => model) || []
			allModels.push(...models)

			nextPageToken = data.nextPageToken
		} while (nextPageToken)

		return matchModelData(
			allModels.map((model) => model.name.replace("models/", "")),
			this.name,
			referenceModels,
			(_, idx) => this.identifyModel(allModels[idx], referenceModels),
		)
	}
	identifyModel(model: ModelBaseInfo, models: ProviderModelFullInfo[]): ProviderModel | undefined {
		// Gemini                                ->  OpenRouter
		// models/gemini-2.0-flash-live-001      ->  google/gemini-2.0-flash-001
		// models/gemini-2.5-flash-live-preview  ->  google/gemini-2.5-flash-preview-09-2025

		const modelBaseName = model.name.replace("models/", "").replace("-live-", "-")
		const slug = `google/${modelBaseName}`
		const match = models.find((m) => m.id.startsWith(slug))
		if (match) {
			return {
				...match,
				providerId: model.name,
				globalId: match.id,
				name: model.displayName || match.name,
				description: model.description || match.description,
				context_length: model.inputTokenLimit || match.context_length,
				max_completion_tokens: model.outputTokenLimit || match.top_provider.max_completion_tokens,
			}
		}
		return undefined
	}
}
