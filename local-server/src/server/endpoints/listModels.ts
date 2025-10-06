import { Request, Response, Router } from "express"
import { UserFacingError } from "../errors"
import { ListModelsInput, ListModelsOutput } from "../schemas/listModelsSchema"
import { AIProvider, ProviderModelFullInfo } from "../providers/provider"
import { deduplicate, listReferenceModels } from "../providers/provider-utils"

let cachedRequest:
	| {
			expiresAt: number
			models: Promise<ProviderModelFullInfo[]>
	  }
	| undefined = undefined

const getProviderModelFullInfosWithCaching = async (): Promise<ProviderModelFullInfo[]> => {
	if (cachedRequest && cachedRequest.expiresAt > Date.now()) {
		return cachedRequest.models
	}
	const promise = listReferenceModels()
	cachedRequest = {
		expiresAt: Date.now() + 1000 * 60, // 1mn hours
		models: promise,
	}
	return promise
}

export const registerEndpoint = (router: Router, modelProviders: AIProvider[]) => {
	router.post("/models", async (req: Request, res: Response) => {
		const body = req.body as ListModelsInput
		// Input validation
		if (!body.provider) {
			throw new UserFacingError({
				message: "Request body is missing required fields",
				statusCode: 400,
			})
		}

		const modelProvider = modelProviders.find((provider) => provider.name === body.provider.name)
		if (!modelProvider) {
			// Likely an external agent. // TODO: handle this as well.
			res.json({
				models: [],
			} satisfies ListModelsOutput)
			return
		}
		const allModels = await getProviderModelFullInfosWithCaching()
		let models = await modelProvider.listModels(body.provider.settings, allModels)
		// Ensure no two models have the same global id from a given provider
		models = deduplicate(models)

		res.json({
			models: models.map((model) => ({
				providerId: model.providerId,
				globalId: model.globalId,
				name: model.name,
				description: model.description,
				contextLength: model.context_length,
				maxCompletionTokens: model.max_completion_tokens || 16384,
				inputModalities: model.architecture.input_modalities,
				outputModalities: model.architecture.output_modalities,
				pricing: {
					prompt: parseTokenCost(model.pricing.prompt),
					completion: parseTokenCost(model.pricing.completion),
					image: parseTokenCost(model.pricing.image),
					request: parseTokenCost(model.pricing.request),
					web_search: parseTokenCost(model.pricing.web_search),
					internal_reasoning: parseTokenCost(model.pricing.internal_reasoning),
					input_cache_read: parseTokenCost(model.pricing.input_cache_read),
					input_cache_write: parseTokenCost(model.pricing.input_cache_write),
				},
				createdAt: model.created,
				rankForProgramming: model.rankForProgramming,
			})),
		} satisfies ListModelsOutput)
	})
}

/** Parses a string representation of token cost, to a cost per million of tokens */
function parseTokenCost(cost: string): number
function parseTokenCost(cost: undefined): undefined
function parseTokenCost(cost: string | undefined): number | undefined
function parseTokenCost(cost: string | undefined): number | undefined {
	return cost ? parseFloat(cost) * 1000000 : undefined
}
