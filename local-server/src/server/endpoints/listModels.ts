import { Request, Response, Router } from "express"
import { UserFacingError } from "../errors"
import { ListModelsInput, ListModelsOutput } from "../schemas/listModelsSchema"
import { ModelProvider } from "../providers/provider"

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
			throw new UserFacingError({
				message: `Unsupported API provider ${body.provider.name}.`,
			})
		}
		const models = await modelProvider.listAllModels(body.provider)
		res.json({
			models,
		} satisfies ListModelsOutput)
	})
}
