import { Request, Response, Router } from "express"
import { logInfo } from "../../../../logger"
import { SearchFilesToolOutput } from "../../../schemas/toolsSchema"
import { regexSearchFiles } from "./searchFiles"
import { UserFacingError } from "../../../errors"
import * as path from "path"
import { existsSync } from "fs"
import { SearchFilesRequestInput } from "@/server/schemas/searchFileSchema"

export const registerEndpoint = (router: Router) => {
	router.post("/searchFiles", async (req: Request, res: Response) => {
		logInfo(`searchFiles ${JSON.stringify(req.body)}`)
		if (!req.body || typeof req.body !== "object") {
			throw new UserFacingError({
				message: "No body",
				statusCode: 400,
			})
		}
		const body = req.body as SearchFilesRequestInput
		if (typeof body.directoryPath !== "string") {
			throw new UserFacingError({
				message: "Parameter `directoryPath` must be a string",
				statusCode: 400,
			})
		}
		if (!existsSync(body.directoryPath)) {
			throw new UserFacingError({
				message: `Directory path does not exist: ${body.directoryPath}`,
				statusCode: 404,
			})
		}
		if (typeof body.projectRoot !== "string") {
			throw new UserFacingError({
				message: "Parameter `projectRoot` must be a string",
				statusCode: 400,
			})
		}
		if (typeof body.regex !== "string") {
			throw new UserFacingError({
				message: "Parameter `regex` must be a string",
				statusCode: 400,
			})
		}
		if (body.filePattern && typeof body.filePattern !== "string") {
			throw new UserFacingError({
				message: "Parameter `filePattern` must be a string",
				statusCode: 400,
			})
		}

		const { projectRoot, directoryPath, regex, filePattern } = body
		const cwd = projectRoot
		const response: SearchFilesToolOutput = await regexSearchFiles({
			cwd,
			directoryPath: path.resolve(cwd, directoryPath),
			regex,
			filePattern,
		})

		logInfo(`searchFiles ${JSON.stringify(response)}`)
		res.json(response)
	})
}
