import { Request, Response, Router } from "express"
import { UserFacingError } from "../errors"
import { ListModelsInput, ListModelsOutput } from "../schemas/listModelsSchema"
import { ModelProvider } from "../providers/provider"
import { OpenRoutedModel, OpenRouterModelProvider } from "../providers/open-router"
import { deduplicate } from "../providers/provider-utils"

let cachedRequest:
	| {
			expiresAt: number
			models: Promise<OpenRoutedModel[]>
	  }
	| undefined = undefined

const getOpenRouterModelsWithCaching = async (): Promise<OpenRoutedModel[]> => {
	if (cachedRequest && cachedRequest.expiresAt > Date.now()) {
		return cachedRequest.models
	}
	const promise = new OpenRouterModelProvider().listReferenceModels()
	cachedRequest = {
		expiresAt: Date.now() + 1000 * 60, // 1mn hours
		models: promise,
	}
	return promise
}

export const registerEndpoint = (router: Router, modelProviders: ModelProvider[]) => {
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
		const allModels = await getOpenRouterModelsWithCaching()
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
				maxCompletionTokens: model.max_completion_tokens,
				inputModalities: model.architecture.input_modalities,
				outputModalities: model.architecture.output_modalities,
				pricing: {
					prompt: parseFloat(model.pricing.prompt),
					completion: parseFloat(model.pricing.completion),
					image: model.pricing.image ? parseFloat(model.pricing.image) : undefined,
					request: model.pricing.request ? parseFloat(model.pricing.request) : undefined,
					web_search: model.pricing.web_search ? parseFloat(model.pricing.web_search) : undefined,
					internal_reasoning: model.pricing.internal_reasoning
						? parseFloat(model.pricing.internal_reasoning)
						: undefined,
					input_cache_read: model.pricing.input_cache_read
						? parseFloat(model.pricing.input_cache_read)
						: undefined,
					input_cache_write: model.pricing.input_cache_write
						? parseFloat(model.pricing.input_cache_write)
						: undefined,
				},
			})),
		} satisfies ListModelsOutput)
	})
}
