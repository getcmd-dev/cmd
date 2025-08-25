import { ModelProvider, ModelProviderInput, ModelProviderOutput } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createGoogleGenerativeAI } from "@ai-sdk/google"
import { JSONValue, LanguageModel } from "ai"

export class GeminiModelProvider implements ModelProvider {
	name: APIProviderName = "gemini"
	build(params: ModelProviderInput): ModelProviderOutput {
		const { modelName, apiKey, baseUrl, reasoningBudget } = params
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
}
