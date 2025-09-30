import { ModelBaseInfo, ModelProvider, ModelProviderInput, ModelProviderOutput } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createOpenAI, OpenAIResponsesProviderOptions } from "@ai-sdk/openai"

export class OpenAIModelProvider implements ModelProvider {
	name: APIProviderName = "openai"
	build(params: ModelProviderInput): ModelProviderOutput {
		const { modelName, apiKey, baseUrl, reasoningBudget } = params
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
	async listAllModels(params: ModelProviderInput): Promise<ModelBaseInfo[]> {
		const baseUrl = process.env["OPENAI_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "https://api.openai.com"
		const allModels: ModelBaseInfo[] = []
		let afterId: string | undefined = undefined

		const headers = {}
		if (params.apiKey) {
			headers["Authorization"] = `Bearer ${params.apiKey}`
		}

		do {
			const url = new URL(`${baseUrl}/v1/models`)
			if (afterId) {
				url.searchParams.set("after_id", afterId)
			}
			const response = await fetch(url.toString(), {
				headers,
			})
			if (!response.ok) {
				throw new Error(`Failed to fetch models: ${response.status} ${response.statusText}`)
			}
			const data = await response.json()
			const models: ModelBaseInfo[] =
				data.data?.map(
					(model: { id: string; display_name: string }): ModelBaseInfo => ({
						id: model.id,
						displayName: model.display_name,
					}),
				) || []
			allModels.push(...models)

			afterId = data.has_more ? data.last_id : undefined
		} while (afterId)

		return allModels
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
