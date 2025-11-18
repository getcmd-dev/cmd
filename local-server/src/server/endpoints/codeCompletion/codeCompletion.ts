import { Request, Response, Router } from "express"
import { logError, logInfo, saveLogToFile } from "../../../logger"
import { AIProvider } from "../../providers/provider"
import { CodeCompletionRequestParams, CodeCompletionResponseParams } from "../../schemas/codeCompletionSchema"
import { addUserFacingError, UserFacingError } from "../../errors"
import { Mistral } from "@mistralai/mistralai"
import { notUndefined } from "@/utils/typeChecks"

export const registerEndpoint = (router: Router, aiProviders: AIProvider[]) => {
	router.post("/completeCode", async (req: Request, res: Response) => {
		if (!req.body) {
			throw new UserFacingError({
				message: "Missing body",
				statusCode: 400,
			})
		}
		logInfo("Received request to /sendMessage endpoint")

		try {
			const body = req.body as CodeCompletionRequestParams

			// const aiProvider = aiProviders.find((provider) => provider.name === body.provider.name)
			// if (!aiProvider) {
			// 	throw new UserFacingError({
			// 		message: `Unsupported API provider ${body.provider.name}.`,
			// 	})
			// }
			// const modelName = body.model
			// const { model } = await aiProvider.build({
			// 	provider: body.provider.settings,
			// 	modelName,
			// })
			// if (!model) {
			// 	throw new UserFacingError({
			// 		message: `Unsupported model: ${modelName} is not supported by ${body.provider.name}.`,
			// 	})
			// }

			// Cleanup when disconnected
			const abortController = new AbortController()
			let responseCompletedByServer = false
			res.on("finish", () => {
				responseCompletedByServer = true
			})
			res.on("close", () => {
				if (!responseCompletedByServer) {
					logInfo("Response closed (client disconnected), aborting the request.")
					abortController.abort()
				}
			})
			res.on("error", (err) => {
				logInfo(`Response error: ${err.message}, aborting the request.`)
				abortController.abort()
			})

			// build prefix
			const prefix = (() => {
				let prefix = ""
				const maxPrefixLength = 10000
				const minCodeLines = 10
				if (body.pasteboardContent) {
					prefix = `<pasteboard>${body.pasteboardContent}</pasteboard>\n${prefix}`
				}
				if (body.recentEdits) {
					prefix = `<recent-edits>${body.recentEdits}</recent-edits>\n${prefix}`
				}
				const prefixLines = body.prefix.split("\n").reverse()
				let selectedPrefixLinesCount = 0
				let budget = maxPrefixLength - prefix.length
				for (const line of prefixLines) {
					if (budget <= 0) {
						break
					}
					budget -= line.length + 1 // +1 for the newline character
					selectedPrefixLinesCount += 1
				}
				selectedPrefixLinesCount = Math.min(selectedPrefixLinesCount, minCodeLines)
				prefix = `${prefix}\n${prefixLines.slice(0, selectedPrefixLinesCount).join("\n")}`
				return prefix
			})()

			// build suffix
			const suffix = (() => {
				if (!body.suffix) {
					return undefined
				}
				const maxSuffixLength = 10000
				const minCodeLines = 10
				const suffixLines = body.suffix.split("\n")
				let selectedSuffixLinesCount = 0
				let budget = maxSuffixLength
				for (const line of suffixLines) {
					if (budget <= 0) {
						break
					}
					budget -= line.length + 1 // +1 for the newline character
					selectedSuffixLinesCount += 1
				}
				selectedSuffixLinesCount = Math.min(selectedSuffixLinesCount, minCodeLines)
				return suffixLines.slice(0, selectedSuffixLinesCount).join("\n")
			})()

			const client = new Mistral({ apiKey: "zT7jUXi9QQCEtC0Naedtu3dOhoSRfEbm" })
			const result = await client.fim.complete({
				model: "codestral-latest",
				prompt: prefix,
				suffix: suffix,
				// temperature: 0,
				// minTokens: 1, // Uncomment to enforce completions to at least 1 token
			})
			const response = {
				choices: result.choices
					.map((choice) => {
						if (typeof choice.message.content === "string") {
							return {
								text: choice.message.content,
							}
						} else {
							return undefined
						}
					})
					.filter(notUndefined),
			} satisfies CodeCompletionResponseParams

			res.write(JSON.stringify(response))
			res.end()
		} catch (error) {
			const logFile = saveLogToFile("failed_send_message.json", JSON.stringify(req.body, null, 2))
			logInfo(`Request body that led to error saved to ${logFile}`)
			logError(error)

			throw addUserFacingError(error, "Failed to process message.")
		}
	})
}
