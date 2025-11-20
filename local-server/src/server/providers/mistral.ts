import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createMistral, MistralLanguageModelOptions } from "@ai-sdk/mistral"
import { UserFacingError } from "../errors"
import { ProviderModelFullInfo } from "./provider"
import { matchModelData } from "./provider-utils"
import { BaseModelCard } from "@mistralai/mistralai/models/components"
import { notUndefined } from "@/utils/typeChecks"

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
		let allModels = data.data?.map((model: BaseModelCard): BaseModelCard => model) || []

		// Remove some models that are not relevant for coding
		const ignoredModelsPrefix = [
			"codestral-embed",
			"mistral-embed",
			"pixtral",
			"voxtral",
			"mistral-moderation",
			"mistral-ocr",
			"open-mistral",
			"ministral",
			"mistral-tiny",
		]
		allModels = allModels.filter((model) => !ignoredModelsPrefix.some((prefix) => model.id.startsWith(prefix)))

		let models = [
			...matchModelData(
				allModels.map((model) => model.id),
				this.name,
				referenceModels,
				(_, idx) => this.identifyModel(allModels[idx], referenceModels),
			),
		]

		// Only keep latest model for each model category
		const modelCategories = [
			"codestral",
			"devstral-small",
			"devstral-medium",
			"mistral-small",
			"mistral-medium",
			"mistral-large",
			"magistral-small",
			"magistral-medium",
		]
		const latestModels: { [key: string]: ProviderModel | undefined } = modelCategories.reduce((acc, category) => {
			return {
				...acc,
				[category]: models
					.filter((model) => model.providerId.startsWith(category))
					.sort((a, b) => (b.name < a.name ? 1 : -1))[0],
			}
		}, {})
		models = models
			.map((model) => {
				const category = modelCategories.find((c) => model.providerId.startsWith(c))
				if (!category) {
					return model
				}
				const latestModel = latestModels[category]
				if (latestModel?.providerId === model.providerId) {
					return {
						...model,
						globalId: `mistralai/${category}-latest`,
						// Remove trailing number
						name: model.name.replace(/\s+\d+(\.\d+)*$/, ""),
					}
				} else {
					// Only keep latest
					return undefined
				}
			})
			.filter(notUndefined)
		return models
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
	fim(
		providerId: string,
	): ((params: { prefix: string; suffix: string }, config: ProviderConfig) => Promise<string>) | undefined {
		// Check if model supports FIM (codestral models do)
		const modelName = providerId.toLowerCase()
		if (!modelName.includes("codestral") && !modelName.includes("code")) {
			return undefined
		}

		return async (params: { prefix: string; suffix: string }, config: ProviderConfig) => {
			const baseUrl =
				process.env["MISTRAL_LOCAL_SERVER_PROXY"] || config.baseUrl || "https://codestral.mistral.ai/v1"
			const apiKey = config.apiKey

			const response = await fetch(`${baseUrl}/fim/completions`, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					Authorization: `Bearer ${apiKey}`,
					...(apiKey ? { "x-api-key": apiKey } : {}),
				},
				body: JSON.stringify({
					model: providerId,
					prompt: params.prefix,
					suffix: params.suffix,
					temperature: 0.01,
					max_tokens: 256,
				}),
			})

			if (!response.ok) {
				const errorText = await response.text()
				throw new UserFacingError({
					message: `Mistral FIM request failed: ${response.statusText} - ${errorText}`,
					statusCode: response.status,
				})
			}

			const data = await response.json()
			const completion = data.choices?.[0]?.message?.content || ""
			return completion
		}
	}
}
