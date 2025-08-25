import { ModelProvider, ModelProviderInput, ModelProviderOutput } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createGroq } from "@ai-sdk/groq"
import { JSONValue, LanguageModel } from "ai"

export class GroqModelProvider implements ModelProvider {
	name: APIProviderName = "groq"
	build(params: ModelProviderInput): ModelProviderOutput {
		const { modelName, apiKey, baseUrl, reasoningBudget } = params
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
}
