import { APIProvider } from "./sendMessageSchema"

export interface ListModelsInput {
	provider: APIProvider
}

export interface ListModelsOutput {
	models: Model[]
}

export interface ModelPricing {
	prompt: number
	completion: number
	image: number | undefined
	request: number | undefined
	web_search: number | undefined
	internal_reasoning: number | undefined
	input_cache_read: number | undefined
	input_cache_write: number | undefined
}

export type ModelModality = "text" | "image" | "file" | "audio"

export type Model = {
	providerId: string
	globalId: string
	name: string
	description: string
	/**
	 * @format integer
	 */
	contextLength: number
	/**
	 * @format integer
	 */
	maxCompletionTokens: number
	inputModalities: ModelModality[]
	outputModalities: ModelModality[]
	pricing: ModelPricing
	createdAt: number
	/**
	 * @format integer
	 */
	rankForProgramming: number
}
