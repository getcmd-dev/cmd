import { ModelProvider, ModelProviderInput, ModelProviderOutput } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createGroq } from "@ai-sdk/groq"
import { JSONValue, LanguageModel } from "ai"

export class GroqModelProvider implements ModelProvider {
	name: APIProviderName = "groq"
	build(params: ModelProviderInput): ModelProviderOutput {
		// TODO: Support controlling reasoning.
		const { modelName, apiKey, baseUrl } = params
		const provider = createGroq({
			apiKey: apiKey,
			baseURL: process.env["GROQ_LOCAL_SERVER_PROXY"] ?? baseUrl,
		})
		const providerOptions: Record<string, JSONValue> = {}
		return {
			model: provider(modelName) as unknown as LanguageModel,
			generalProviderOptions: {
				groq: providerOptions,
			},
		}
	}
}
