import { ModelMessage, JSONValue, LanguageModel } from "ai"
import { APIProviderName } from "../schemas/sendMessageSchema"
import { ToolModelWithName } from "../endpoints/sendMessage/sendMessage"

export type ModelProviderOutput = {
	model?: LanguageModel
	generalProviderOptions?: Record<string, Record<string, JSONValue>>
	addProviderOptionsToMessages?: (messages: Array<ModelMessage>) => Array<ModelMessage>
	addProviderOptionsToTools?: (tools: Array<ToolModelWithName> | undefined) => Array<ToolModelWithName> | undefined
}

export type ModelProviderInput = {
	baseUrl?: string
	apiKey?: string
	modelName: string
	reasoningBudget?: number
}
export interface ModelProvider {
	build: (params: ModelProviderInput) => ModelProviderOutput
	name: APIProviderName
}
