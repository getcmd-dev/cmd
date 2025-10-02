import { logInfo } from "@/logger"
import { UserFacingError } from "../errors"
import { OpenRouterModel } from "./open-router"
import { ModelRichInfo } from "./provider"
import { notUndefined } from "@/utils/typeChecks"

export const deduplicate = (models: ModelRichInfo[]): ModelRichInfo[] => {
	const modelsById: { [id: string]: ModelRichInfo } = {}
	models.forEach((model) => {
		const duplicate = modelsById[model.globalId]
		if (!duplicate) {
			modelsById[model.globalId] = model
		} else if (
			stringSimilarity(model.providerId, model.globalId) >
			stringSimilarity(duplicate.providerId, duplicate.globalId)
		) {
			modelsById[model.globalId] = model
		}
	})
	return Object.values(modelsById)
}

const stringSimilarity = (str1: string, str2: string): number => {
	// Handle edge cases
	if (str1 === str2) return 1
	if (str1.length === 0 || str2.length === 0) return 0

	// Calculate Levenshtein distance
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

	// Get the Levenshtein distance
	const distance = matrix[str1.length][str2.length]

	// Convert to similarity score (0 to 1)
	const maxLength = Math.max(str1.length, str2.length)
	return 1 - distance / maxLength
}

/** Fetch a request that returns a list of items under .data */
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

export const matchModelData = (
	modelIds: string[],
	provider: string,
	referenceModels: OpenRouterModel[],
	fallback?: (modelId: string, idx: number) => ModelRichInfo | undefined,
): ModelRichInfo[] => {
	const modelBySlug: { [id: string]: OpenRouterModel } = {}
	referenceModels.forEach((model) => {
		model.providers.forEach((provider) => {
			provider.slugs.forEach((modelSlug) => {
				modelBySlug[modelSlug.toLowerCase()] = model
			})
		})
	})
	return modelIds
		.map((modelId, idx) => {
			const reference = modelBySlug[modelId.toLowerCase()] || modelBySlug[`${provider}/${modelId}`.toLowerCase()]
			if (!reference) {
				const fb = fallback?.(modelId, idx)
				if (!fb) {
					logInfo(`Could not match model ${provider}/${modelId}`)
				} else {
					logInfo(`Identified ${modelId} with fallback`)
				}
				return fb
			}
			return {
				...reference,

				providerId: modelId,
				globalId: reference.id,
				max_completion_tokens: reference.top_provider.max_completion_tokens,
			}
		})
		.filter(notUndefined)
}
