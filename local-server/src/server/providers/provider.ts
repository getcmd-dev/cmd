import { ModelMessage, JSONValue, LanguageModel } from "ai"
import { APIProviderName } from "../schemas/sendMessageSchema"
import { ToolModelWithName } from "../endpoints/sendMessage/sendMessage"
import { OpenRouterModel } from "./open-router"

export type ModelProviderOutput = {
	model?: LanguageModel
	generalProviderOptions?: Record<string, Record<string, JSONValue>>
	addProviderOptionsToMessages?: (messages: Array<ModelMessage>) => Array<ModelMessage>
	addProviderOptionsToTools?: (tools: Array<ToolModelWithName> | undefined) => Array<ToolModelWithName> | undefined
}

export type ModelProviderInput = {
	provider: ProviderConfig
	modelName: string
	reasoningBudget?: number
}

export type ProviderConfig = {
	baseUrl?: string
	apiKey?: string
}

export type ModelModality = "text" | "image" | "file" | "audio"

export type ModelRichInfo = {
	providerId: string
	globalId: string
	name: string
	description: string
	context_length: number
	max_completion_tokens?: number
	architecture: {
		input_modalities: ModelModality[]
		output_modalities: ModelModality[]
	}
	pricing: {
		prompt: string
		completion: string
		image?: string
		request?: string
		web_search?: string
		internal_reasoning?: string
		input_cache_read?: string
		input_cache_write?: string
	}
	/** The creation unix timestamp, in seconds */
	created: number
	rankForProgramming: number
	supportsReasoning: boolean
}

export interface ModelProvider {
	build: (params: ModelProviderInput) => ModelProviderOutput
	name: APIProviderName
	/** List available models */
	listModels: (config: ProviderConfig, referenceModels: OpenRouterModel[]) => Promise<ModelRichInfo[]>
}
