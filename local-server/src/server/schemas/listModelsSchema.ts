export interface ListModelsInput {
	provider: APIProvider
}

export interface APIProvider {
	name: APIProviderName
	settings: {
		apiKey?: string
		baseUrl?: string
	}
}
export type APIProviderName = "openai" | "anthropic" | "openrouter" | "claude_code" | "groq" | "gemini"

export interface Models {
	id: string
	displayName: string
}

export interface ListModelsOutput {
	models: Models[]
}
