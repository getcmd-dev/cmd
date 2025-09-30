import { APIProvider } from "./sendMessageSchema"

export interface ListModelsInput {
	provider: APIProvider
}

export interface Models {
	id: string
	displayName: string
}

export interface ListModelsOutput {
	models: Models[]
}
