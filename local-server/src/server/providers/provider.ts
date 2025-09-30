import { ModelMessage, JSONValue, LanguageModel } from "ai"
import { APIProviderName } from "../schemas/sendMessageSchema"
import { ToolModelWithName } from "../endpoints/sendMessage/sendMessage"
import { OpenRoutedModel } from "./open-router"

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
	max_completion_tokens: number | undefined
	architecture: {
		input_modalities: ModelModality[]
		output_modalities: ModelModality[]
	}
	pricing: {
		prompt: string
		completion: string
		image: string | undefined
		request: string | undefined
		web_search: string | undefined
		internal_reasoning: string | undefined
		input_cache_read: string | undefined
		input_cache_write: string | undefined
	}
}

export interface ModelProvider {
	build: (params: ModelProviderInput) => ModelProviderOutput
	name: APIProviderName
	/** List available models */
	listModels: (config: ProviderConfig, referenceModels: OpenRoutedModel[]) => Promise<ModelRichInfo[]>
}
