import { logInfo } from "@/logger"
import { UserFacingError } from "../errors"
import { ModelModality, ProviderModelFullInfo } from "./provider"
import { ProviderModel } from "./provider"
import { notEmpty, notUndefined } from "@/utils/typeChecks"

/**
 * Fetches detailed information about all AI models from OpenRouter.
 * This serves as reference data for enriching provider-specific model lists.
 *
 * The function fetches from multiple OpenRouter endpoints to gather:
 * - Base model information (context length, pricing, modalities)
 * - Programming-focused ranking data
 * - Provider-specific metadata (known model IDs, endpoints, icons)
 *
 * @returns Array of models with complete cross-provider metadata
 * @throws {UserFacingError} If the fetch request fails
 */
export const listReferenceModels = async (): Promise<ProviderModelFullInfo[]> => {
	type ProviderModelFullInfoResponse = {
		id: string
		canonical_slug: string
		name: string
		description: string
		context_length: number
		architecture: {
			input_modalities: ModelModality[]
			output_modalities: ModelModality[]
		}
		top_provider: {
			context_length: number
			max_completion_tokens?: number
		}
		pricing: {
			prompt: string
			completion: string
			image: string
			request: string
			web_search: string
			internal_reasoning: string
			input_cache_read?: string
			input_cache_write?: string
		}
		created: number
	}

	type OpenRouterFindResponse = {
		permaslug: string
		slug: string
		hf_slug?: string
		endpoint?: {
			provider_model_id: string
			supported_parameters: string[]
			supports_reasoning: boolean
			provider_info: {
				displayName: string
				slug: string
				baseUrl: string
				icon?: {
					url?: string
				}
			}
		}
	}

	// See: https://openrouter.ai/docs/api-reference/list-available-models
	const baseUrl = process.env["OPEN_ROUTER_LOCAL_SERVER_PROXY"] ?? "https://openrouter.ai/api/v1"

	// Fetch data from multiple endpoints in parallel:
	// 1. Models ranked for programming tasks
	// 2. All available models
	// 3. Provider-specific metadata for each model
	const [programmingModels, allModels, modelsWithProviderInfo] = await Promise.all([
		await fetchDataRequest<ProviderModelFullInfoResponse>(`${baseUrl}/models?category=programming`),
		await fetchDataRequest<ProviderModelFullInfoResponse>(`${baseUrl}/models`),
		await fetchDataRequest<OpenRouterFindResponse>(
			`https://openrouter.ai/api/frontend/models/find`,
			(response) => response.data?.models,
		),
	])

	// Create a lookup map for programming ranks (lower index = better rank)
	const programmingRankById = Object.fromEntries(programmingModels.map((model, idx) => [model.id, idx]))

	// Assign ranks to all models (programming models get their actual rank, others get lower priority)
	const rankedModels = allModels.map((model, idx) => ({
		...model,
		rankForProgramming: programmingRankById[model.id] ?? idx + programmingModels.length,
	}))

	// Index provider info by model slug for efficient lookup
	const providersInfoByModelSlug: { [modelSlug: string]: OpenRouterFindResponse[] } = {}
	for (const providerInfo of modelsWithProviderInfo) {
		const modelSlug = providerInfo.permaslug
		if (!providersInfoByModelSlug[modelSlug]) {
			providersInfoByModelSlug[modelSlug] = []
		}
		providersInfoByModelSlug[modelSlug].push(providerInfo)
	}

	// Merge model data with provider-specific information
	return rankedModels
		.map((model) => {
			const modelWithProviders = providersInfoByModelSlug[model.canonical_slug]
			if (!modelWithProviders) {
				// Skip models without provider information
				return undefined
			}
			const name = (() => {
				// Remove the provider prefix (ie `Anthropic: Claude Sonnet 4.5` -> `Claude Sonnet 4.5`)
				// This pattern matching works well for now.
				const spl = model.name.split(":")
				return spl[spl.length - 1].trim()
			})()
			return {
				...model,
				name,
				// A model supports reasoning if at least one provider supports it
				supportsReasoning: !!modelWithProviders.find((provider) => provider.endpoint?.supports_reasoning),
				providers: modelWithProviders
					.map((modelWithProvider) => {
						if (!modelWithProvider.endpoint) {
							return undefined
						}
						return {
							slug: modelWithProvider.endpoint.provider_info.slug,
							displayName: modelWithProvider.endpoint.provider_info.displayName,
							baseUrl: modelWithProvider.endpoint.provider_info.baseUrl,
							iconUrl: modelWithProvider.endpoint.provider_info.icon?.url,
							// Collect all known identifiers for this model from this provider
							known_appelations: [
								modelWithProvider.endpoint.provider_model_id,
								model.canonical_slug,
								modelWithProvider.slug,
								modelWithProvider.permaslug,
								modelWithProvider.hf_slug,
							].filter(notEmpty),
						}
					})
					.filter(notUndefined),
			}
		})
		.filter(notUndefined)
}

/**
 * Removes duplicate models from a list, keeping the one with the most similar
 * provider ID to the global ID.
 *
 * When multiple providers serve the same model with different IDs, this function
 * keeps the entry where the provider's ID most closely matches the canonical global ID.
 * This helps ensure we use the most "natural" or "official" identifier.
 *
 * @param models - Array of models potentially containing duplicates
 * @returns Deduplicated array of models
 */
export const deduplicate = (models: ProviderModel[]): ProviderModel[] => {
	const modelsById: { [id: string]: ProviderModel } = {}
	models.forEach((model) => {
		const duplicate = modelsById[model.globalId]
		if (!duplicate) {
			modelsById[model.globalId] = model
		} else if (
			// Prefer the model whose provider ID is more similar to the global ID
			stringSimilarity(model.providerId, model.globalId) >
			stringSimilarity(duplicate.providerId, duplicate.globalId)
		) {
			modelsById[model.globalId] = model
		}
	})
	return Object.values(modelsById)
}

/**
 * Calculates string similarity using Levenshtein distance.
 * Returns a value between 0 (completely different) and 1 (identical).
 *
 * @param str1 - First string to compare
 * @param str2 - Second string to compare
 * @returns Similarity score from 0 to 1
 */
const stringSimilarity = (str1: string, str2: string): number => {
	// Handle edge cases
	if (str1 === str2) return 1
	if (str1.length === 0 || str2.length === 0) return 0

	// Calculate Levenshtein distance using dynamic programming
	const matrix: number[][] = []

	// Initialize first column
	for (let i = 0; i <= str1.length; i++) {
		matrix[i] = [i]
	}

	// Initialize first row
	for (let j = 0; j <= str2.length; j++) {
		matrix[0][j] = j
	}

	// Fill in the matrix
	for (let i = 1; i <= str1.length; i++) {
		for (let j = 1; j <= str2.length; j++) {
			if (str1[i - 1] === str2[j - 1]) {
				matrix[i][j] = matrix[i - 1][j - 1]
			} else {
				matrix[i][j] = Math.min(
					matrix[i - 1][j] + 1, // deletion
					matrix[i][j - 1] + 1, // insertion
					matrix[i - 1][j - 1] + 1, // substitution
				)
			}
		}
	}

	// Get the Levenshtein distance (minimum number of edits needed)
	const distance = matrix[str1.length][str2.length]

	// Convert distance to similarity score (0 = completely different, 1 = identical)
	const maxLength = Math.max(str1.length, str2.length)
	return 1 - distance / maxLength
}

/**
 * Fetches data from an API endpoint that returns a list of items.
 *
 * @template Response - The type of items in the response array
 * @param url - The URL to fetch from
 * @param getData - Function to extract the data array from the response (defaults to response.data)
 * @returns Array of items from the response
 * @throws {UserFacingError} If the request fails
 */
export const fetchDataRequest = async <Response>(
	url: string,
	getData: (unknown) => Response[] | undefined = (response) => response.data,
): Promise<Response[]> => {
	const response = await fetch(new URL(url).toString())
	if (!response.ok) {
		throw new UserFacingError({
			message: response.statusText,
			statusCode: response.status,
			underlyingError: new Error(`Failed to fetch models for provider`),
		})
	}
	const data = await response.json()
	return getData(data) || []
}

/**
 * Matches provider-specific model IDs to reference model data.
 *
 * This function enriches a provider's model list by matching their IDs
 * against reference data from OpenRouter. It tries multiple matching strategies:
 * 1. Direct match on known model appelations
 * 2. Match with provider prefix (e.g., "openai/gpt-4")
 * 3. Fallback function if provided
 *
 * @param modelIds - Array of model IDs from the provider
 * @param provider - The provider name (used for prefixed matching)
 * @param referenceModels - Reference model data to match against
 * @param fallback - Optional function to create model data if no match found
 * @returns Array of enriched provider models
 */
export const matchModelData = (
	modelIds: string[],
	provider: string,
	referenceModels: ProviderModelFullInfo[],
	fallback?: (modelId: string, idx: number) => ProviderModel | undefined,
): ProviderModel[] => {
	// Build a lookup map of all known model identifiers
	const modelBySlug: { [id: string]: ProviderModelFullInfo } = {}
	referenceModels.forEach((model) => {
		model.providers.forEach((provider) => {
			provider.known_appelations.forEach((modelSlug) => {
				modelBySlug[modelSlug.toLowerCase()] = model
			})
		})
	})

	return modelIds
		.map((modelId, idx) => {
			// Try to match the model ID directly, or with provider prefix
			const reference = modelBySlug[modelId.toLowerCase()] || modelBySlug[`${provider}/${modelId}`.toLowerCase()]
			if (!reference) {
				// No match found - try fallback if provided
				const fb = fallback?.(modelId, idx)
				if (!fb) {
					logInfo(`Could not match model ${provider}/${modelId}`)
				} else {
					logInfo(`Identified ${modelId} with fallback`)
				}
				return fb
			}

			// Merge reference data with provider-specific ID
			return {
				...reference,
				providerId: modelId,
				globalId: reference.id,
				max_completion_tokens: reference.top_provider.max_completion_tokens,
			}
		})
		.filter(notUndefined)
}
