import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createMistral, MistralLanguageModelOptions } from "@ai-sdk/mistral"
import { UserFacingError } from "../errors"
import { ProviderModelFullInfo } from "./provider"
import { matchModelData } from "./provider-utils"
import { notUndefined } from "@/utils/typeChecks"
import { Model } from "openai/resources/models.mjs"
import { buildFIMRequest, CodeCompletionRequestParams } from "../endpoints/codeCompletion/helpers"
import { CodeCompletionResponseParams } from "../schemas/codeCompletionSchema"

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
		const baseUrl = process.env["MISTRAL_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "https://api.mistral.ai/v1"

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
		let allModels = data.data?.map((model: Model): Model => model) || []

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
		allModels = allModels
			.filter((model) => !ignoredModelsPrefix.some((prefix) => model.id.startsWith(prefix)))
			.filter((model) => !knownUnmatchedModels.includes(model.id))

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
	private identifyModel(model: Model, models: ProviderModelFullInfo[]): ProviderModel | undefined {
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
				supportsChat: true,
				supportsCompletion: model.id.startsWith("codestral"),
			}
		}
		return undefined
	}
	fim(
		modelProviderId: string,
	):
		| ((params: CodeCompletionRequestParams, config: ProviderConfig) => Promise<CodeCompletionResponseParams>)
		| undefined {
		// Check if model supports FIM (codestral models do)
		const modelName = modelProviderId.toLowerCase()
		if (!modelName.includes("codestral") && !modelName.includes("code")) {
			return undefined
		}

		return async (params: CodeCompletionRequestParams, config: ProviderConfig) => {
			const fimRequest = buildFIMRequest(params)

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
					model: modelProviderId,
					prompt: fimRequest.prompt,
					suffix: fimRequest.suffix,
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
			const completion = (data.choices?.[0]?.message?.content || "") as string
			return {
				choices: [
					{
						text: completion,
						changedRange: {
							start: params.selection.start,
							end: params.selection.end,
						},
					},
				],
			} satisfies CodeCompletionResponseParams
		}
	}
}

const knownUnmatchedModels = [
	"mistral-large-latest",
	"mistral-medium-latest",
	"mistral-medium",
	"mistral-large-pixtral-2411",
	"codestral-latest",
	"devstral-small-2507",
	"devstral-small-latest",
	"devstral-medium-latest",
	"mistral-small-2506",
	"mistral-small-latest",
	"magistral-medium-2509",
	"magistral-medium-latest",
	"magistral-small-2509",
	"magistral-small-latest",
	"magistral-small-2507",
	"magistral-medium-2507",
	"codestral-2412",
	"codestral-2411-rc5",
	"mistral-small-2503",
	"mistral-small-2501",
	"mistral-large-latest",
	"mistral-medium-latest",
	"mistral-medium",
	"mistral-large-pixtral-2411",
	"codestral-latest",
	"devstral-small-2507",
	"devstral-small-latest",
	"devstral-medium-latest",
	"mistral-small-2506",
	"mistral-small-latest",
	"magistral-medium-2509",
	"magistral-medium-latest",
	"magistral-small-2509",
	"magistral-small-latest",
	"magistral-small-2507",
	"magistral-medium-2507",
	"codestral-2412",
	"codestral-2411-rc5",
	"mistral-small-2503",
	"mistral-small-2501",
]
