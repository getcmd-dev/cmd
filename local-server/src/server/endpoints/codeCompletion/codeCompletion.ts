import { Request, Response, Router } from "express"
import { logError, logInfo, saveLogToFile } from "../../../logger"
import { AIProvider } from "../../providers/provider"
import { CodeCompletionRequestParams, CodeCompletionResponseParams } from "../../schemas/codeCompletionSchema"
import { addUserFacingError, UserFacingError } from "../../errors"
import { streamText } from "ai"
import { buildRequest, buildInstructPrompt, processInstructCompletion } from "./helpers"

export const registerEndpoint = (router: Router, aiProviders: AIProvider[]) => {
	router.post("/completeCode", async (req: Request, res: Response) => {
		if (!req.body) {
			throw new UserFacingError({
				message: "Missing body",
				statusCode: 400,
			})
		}
		logInfo("Received request to /completeCode endpoint")

		try {
			const body = req.body as CodeCompletionRequestParams

			// Find the AI provider
			const aiProvider = aiProviders.find((provider) => provider.name === body.provider.name)
			if (!aiProvider) {
				throw new UserFacingError({
					message: `Unsupported API provider ${body.provider.name}.`,
				})
			}

			// Determine completion mode
			const modelName = body.model
			const fim = aiProvider.fim?.(modelName)
			const nextEdit = aiProvider.nextEdit?.(modelName)

			// logInfo(`Using completion mode: ${mode}`)

			// Build the context request
			const requestResult = buildRequest({
				prefix: body.prefix,
				suffix: body.suffix,
				pasteboardContent: body.pasteboardContent,
				recentEdits: body.recentEdits,
				recentlyOpenedFiles: body.recentlyOpenedFiles,
				filepath: body.filepath,
				cursorPosition: body.selection.start,
				formattingMetadata: body.formattingMetadata,
			})

			logInfo(
				`Code completion request built: ${JSON.stringify({
					snippetsIncluded: requestResult.context.snippetsIncluded,
					tokensUsed: requestResult.context.tokensUsed,
				})}`,
			)

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

			let completion: string
			let fullFileContent: string
			let changedRange:
				| {
						start: { line: number; character: number }
						end: { line: number; character: number }
				  }
				| undefined

			// Execute based on mode
			if (fim) {
				// Use FIM endpoint
				completion = await fim(
					{
						prefix: requestResult.prompt,
						suffix: requestResult.suffix || "",
					},
					body.provider.settings,
				)

				// Process FIM completion to get full file content
				fullFileContent = body.prefix + completion + body.suffix
				changedRange = {
					start: body.selection.start,
					end: body.selection.start,
				}
			} else if (nextEdit) {
				// Use Next Edit endpoint (if provider supports it)
				completion = await nextEdit(
					{
						prefix: body.prefix,
						suffix: body.suffix,
						pasteboardContent: body.pasteboardContent,
						recentEdits: body.recentEdits,
						recentlyOpenedFiles: body.recentlyOpenedFiles,
						filepath: body.filepath,
						cursorPosition: body.selection.start,
						formattingMetadata: body.formattingMetadata,
					},
					body.provider.settings,
				)

				// For next edit, the completion IS the full file content
				fullFileContent = completion
			} else {
				// Use chat completion with instruct-style prompt
				const { model, generalProviderOptions, addProviderOptionsToMessages } = await aiProvider.build({
					provider: body.provider.settings,
					modelName,
				})

				if (!model) {
					throw new UserFacingError({
						message: `Failed to build model for ${modelName}.`,
					})
				}

				// Build instruct prompt
				const instructPrompt = buildInstructPrompt({
					prefix: body.prefix,
					suffix: body.suffix,
					cursorPosition: body.selection.start,
					editableRangeMargin: { top: 0, bottom: 5 },
					recentEdits: body.recentEdits,
					contextSnippets: [], // Could add context snippets here
					filepath: body.filepath,
					commentPrefix: `//`,
				})

				// Call chat completion
				const messages = [
					{
						role: "system" as const,
						content: instructPrompt.systemPrompt,
					},
					{
						role: "user" as const,
						content: instructPrompt.userPrompt,
					},
				]

				const result = await streamText({
					model,
					abortSignal: abortController.signal,
					messages: addProviderOptionsToMessages ? addProviderOptionsToMessages(messages) : messages,
					providerOptions: generalProviderOptions,
					maxOutputTokens: 2048,
				})

				// Collect the full text
				let instructCompletion = ""
				for await (const chunk of result.textStream) {
					instructCompletion += chunk
				}

				completion = instructCompletion

				// Process instruct completion to get full file content
				const processResult = processInstructCompletion(
					body.prefix,
					body.suffix,
					instructPrompt.editableRegionStart,
					instructPrompt.editableRegionEnd,
					completion,
				)
				fullFileContent = processResult.fullFileContent
				changedRange = processResult.changedRange
			}

			const response: CodeCompletionResponseParams = {
				choices: [
					{
						text: completion,
						newContent: fullFileContent,
						changedRange,
					},
				],
			}

			res.write(JSON.stringify(response))
			res.end()
		} catch (error) {
			const logFile = saveLogToFile("failed_complete_code.json", JSON.stringify(req.body, null, 2))
			logInfo(`Request body that led to error saved to ${logFile}`)
			logError(error)

			throw addUserFacingError(error, "Failed to process code completion.")
		}
	})
}
