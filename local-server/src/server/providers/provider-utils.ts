import { ModelRichInfo } from "./provider"

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
