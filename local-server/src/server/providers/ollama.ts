import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig, ModelModality } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createOllama } from "ollama-ai-provider-v2"
import { LanguageModel } from "ai"
import { UserFacingError } from "../errors"
import { ProviderModelFullInfo } from "./provider"

type OllamaModelInfo = {
	name: string
	model: string
	modified_at: string
	size: number
	digest: string
	details: {
		parent_model?: string
		format: string
		family: string
		families?: string[]
		parameter_size: string
		quantization_level: string
	}
}

type OllamaModelsResponse = {
	models: OllamaModelInfo[]
}

type OllamaModelDetails = {
	model_info: {
		"general.architecture"?: string
		"general.base_model.0.name"?: string
		"general.base_model.0.organization"?: string
		"general.parameter_count"?: number
		"general.size_label"?: string
		"general.license"?: string
		[key: string]: string | number | null | undefined
	}
	details: {
		parent_model: string
		format: string
		family: string
		families?: string[]
		parameter_size: string
		quantization_level: string
	}
	capabilities?: string[]
	license?: string
	template?: string
	system?: string
}

// Extract context length from model_info
function extractContextLength(modelInfo: Record<string, string | number | null | undefined>): number {
	// Search for any key ending with ".context_length"
	const contextLengthKey = Object.keys(modelInfo).find((key) => key.endsWith(".context_length"))

	if (contextLengthKey) {
		const value = modelInfo[contextLengthKey]
		if (typeof value === "number" && value > 0) {
			return value
		}
	}

	// Default fallback
	return 4096
}

// Derive input modalities from Ollama capabilities
function deriveInputModalities(capabilities?: string[]): ModelModality[] {
	if (!capabilities || capabilities.length === 0) {
		return ["text"]
	}

	const modalities = new Set<ModelModality>(["text"]) // All Ollama models support text

	// Check for vision capabilities
	if (capabilities.includes("vision")) {
		modalities.add("image")
	}

	return Array.from(modalities)
}

export class OllamaAIProvider implements AIProvider {
	name: APIProviderName = "ollama"

	build(params: AIProviderInput): AIProviderOutput {
		const {
			provider: { baseUrl },
			modelName,
		} = params

		let finalBaseUrl = process.env["OLLAMA_LOCAL_SERVER_PROXY"] ?? baseUrl ?? "http://localhost:11434/api"
		if (!finalBaseUrl.endsWith("/api")) {
			finalBaseUrl = `${finalBaseUrl}/api`
		}

		const provider = createOllama({
			baseURL: finalBaseUrl,
		})

		return {
			model: provider(modelName) as unknown as LanguageModel,
			generalProviderOptions: {},
		}
	}

	async listModels(params: ProviderConfig, referenceModels: ProviderModelFullInfo[]): Promise<ProviderModel[]> {
		let baseUrl = process.env["OLLAMA_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "http://localhost:11434/api"
		if (!baseUrl.endsWith("/api")) {
			baseUrl = `${baseUrl}/api`
		}

		// List available models
		const url = new URL(`${baseUrl}/tags`)
		const response = await fetch(url.toString())

		if (!response.ok) {
			throw new UserFacingError({
				message: `Failed to fetch Ollama models: ${response.statusText}`,
				statusCode: response.status,
				underlyingError: new Error(`Failed to fetch models for Ollama provider`),
			})
		}

		const data: OllamaModelsResponse = await response.json()
		const allModels = data.models || []

		// Fetch detailed information for each model in parallel
		const modelsWithDetails = await Promise.all(
			allModels.map(async (model) => {
				const details = await this.fetchModelDetails(baseUrl, model.name)
				if (!details) {
					return undefined
				}
				return { model, details }
			}),
		).then((results) =>
			results.filter(
				(item): item is { model: OllamaModelInfo; details: OllamaModelDetails } => item !== undefined,
			),
		)

		return modelsWithDetails.map(({ model, details }) => this.buildModel(model, details))
	}

	/**
	 * Fetch detailed information about a specific model from Ollama API
	 */
	private async fetchModelDetails(baseUrl: string, modelName: string): Promise<OllamaModelDetails | null> {
		try {
			const response = await fetch(`${baseUrl}/show`, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
				},
				body: JSON.stringify({ name: modelName }),
			})

			if (!response.ok) {
				// If we can't get details, return null
				return null
			}

			return await response.json()
		} catch (error) {
			// Silently fail and return null
			return null
		}
	}

	private buildModel(model: OllamaModelInfo, details: OllamaModelDetails): ProviderModel {
		// Extract general information from details
		const displayName = details.model_info?.["general.base_model.0.name"] || model.name
		const organization = details.model_info?.["general.base_model.0.organization"]
		const sizeLabel = details.model_info?.["general.size_label"] || model.details.parameter_size

		// Build description with available information
		let description = `Ollama: ${model.details.family}`
		if (organization) {
			description = `${organization} - ${displayName}`
		}
		if (sizeLabel) {
			description += ` (${sizeLabel})`
		}

		// Extract context length from detailed model info if available, fallback to Ollama default
		const contextLength = details.model_info ? extractContextLength(details.model_info) : 4096

		// Derive input modalities from capabilities
		const inputModalities = deriveInputModalities(details.capabilities)

		// Calculate rank for programming from model name
		const rankForProgramming =
			model.name.toLowerCase().includes("code") || model.name.toLowerCase().startsWith("dev") ? 100 : 0

		// Return model information
		return {
			providerId: model.name,
			globalId: `ollama/${model.name}`,
			name: displayName,
			description: description,
			context_length: contextLength,
			architecture: {
				input_modalities: inputModalities,
				output_modalities: ["text"],
			},
			created: new Date(model.modified_at).getTime() / 1000,
			rankForProgramming: rankForProgramming,
			supportsReasoning: details.capabilities?.includes("thinking") ?? false,
			supportsCompletion: details.capabilities?.includes("insert") ?? false,
			supportsChat: details.capabilities?.includes("completion") ?? false,
		}
	}
}
