import { AIProvider, AIProviderInput, AIProviderOutput, ProviderModel, ProviderConfig } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { UserFacingError } from "../errors"
import { ProviderModelFullInfo } from "./provider"
import { matchModelData } from "./provider-utils"
import { CodeCompletionRequestParams } from "../endpoints/codeCompletion/helpers"
import { createOpenAI, OpenAIResponsesProviderOptions } from "@ai-sdk/openai"
import { Model } from "openai/resources/models.mjs"
import { CodeCompletionResponseParams, CursorRange } from "../schemas/codeCompletionSchema"
import { logInfo } from "@/logger"

// Mercury-Coder specific tokens
const INCEPTION_RECENTLY_VIEWED_CODE_SNIPPETS_OPEN = "<|recently_viewed_code_snippets|>"
const INCEPTION_RECENTLY_VIEWED_CODE_SNIPPETS_CLOSE = "<|/recently_viewed_code_snippets|>"
const INCEPTION_RECENTLY_VIEWED_CODE_SNIPPET_OPEN = "<|recently_viewed_code_snippet|>"
const INCEPTION_RECENTLY_VIEWED_CODE_SNIPPET_CLOSE = "<|/recently_viewed_code_snippet|>"
const INCEPTION_CURRENT_FILE_CONTENT_OPEN = "<|current_file_content|>"
const INCEPTION_CURRENT_FILE_CONTENT_CLOSE = "<|/current_file_content|>"
const INCEPTION_CODE_TO_EDIT_OPEN = "<|code_to_edit|>"
const INCEPTION_CODE_TO_EDIT_CLOSE = "<|/code_to_edit|>"
const INCEPTION_EDIT_DIFF_HISTORY_OPEN = "<|edit_diff_history|>"
const INCEPTION_EDIT_DIFF_HISTORY_CLOSE = "<|/edit_diff_history|>"
const INCEPTION_CURSOR = "<|cursor|>"

export class InceptionAIProvider implements AIProvider {
	name: APIProviderName = "inception"
	build(params: AIProviderInput): AIProviderOutput {
		const {
			provider: { apiKey, baseUrl },
			modelName,
			reasoningBudget,
		} = params
		const provider = createOpenAI({
			apiKey: apiKey,
			baseURL: process.env["INCEPTION_LOCAL_SERVER_PROXY"] ?? baseUrl,
			// fetch: openAiFetch,
		})
		const providerOptions: OpenAIResponsesProviderOptions = {
			parallelToolCalls: true,
		}

		if (reasoningBudget) {
			providerOptions.reasoningEffort = "medium" // low, medium, and high
		}
		return {
			model: provider(modelName),

			generalProviderOptions: {
				openai: providerOptions,
			},
		}
	}

	async listModels(params: ProviderConfig, referenceModels: ProviderModelFullInfo[]): Promise<ProviderModel[]> {
		const baseUrl =
			process.env["INCEPTION_LOCAL_SERVER_PROXY"] ?? params.baseUrl ?? "https://api.inceptionlabs.ai/v1"

		const headers = {}
		if (params.apiKey) {
			headers["Authorization"] = `Bearer ${params.apiKey}`
		}

		const url = new URL(`${baseUrl}/models`)
		const response = await fetch(url.toString(), {
			headers,
		})
		if (!response.ok) {
			throw new UserFacingError({
				message: `Failed to fetch models: ${response.statusText}}`,
				statusCode: response.status,
			})
		}
		const data = await response.json()
		const allModels = data.data?.map((model: Model): Model => model) || []

		return matchModelData(
			allModels.map((model) => model.id),
			this.name,
			referenceModels,
			(_, idx) => this.identifyModel(allModels[idx], referenceModels),
		)
	}

	nextEdit(
		modelProviderId: string,
	):
		| ((params: CodeCompletionRequestParams, config: ProviderConfig) => Promise<CodeCompletionResponseParams>)
		| undefined {
		// All mercury-coder models support next-edit
		return async (params: CodeCompletionRequestParams, config: ProviderConfig) => {
			const baseUrl =
				process.env["INCEPTION_LOCAL_SERVER_PROXY"] || config.baseUrl || "https://api.inceptionlabs.ai/v1"
			const apiKey = config.apiKey

			if (!apiKey) {
				throw new UserFacingError({
					message: "API key is required for Inception",
				})
			}

			if (!params.prefix || !params.suffix) {
				throw new UserFacingError({
					message: "prefix and suffix are required for next-edit completion",
				})
			}

			// Build the prompt in Mercury-Coder format
			const { prompt, editableRegionRange } = this.buildInceptionNextEditPrompt(params)
			logInfo(`Editable region range: ${JSON.stringify(editableRegionRange)}`)

			const response = await fetch(`${baseUrl}/edit/completions`, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					Authorization: `Bearer ${apiKey}`,
				},
				body: JSON.stringify({
					model: modelProviderId,
					messages: [
						{
							role: "user",
							content: prompt,
						},
					],
					max_tokens: 2048,
					temperature: 0.0,
					stream: false,
				}),
			})

			if (!response.ok) {
				const errorText = await response.text()
				throw new UserFacingError({
					message: `Mercury-Coder request failed: ${response.statusText} - ${errorText}`,
					statusCode: response.status,
				})
			}

			const data = await response.json()
			const completion = (data.choices?.[0]?.message?.content || "") as string

			// Extract code from markdown code blocks
			return {
				choices: [
					{
						text: this.extractCodeFromResponse(completion),
						changedRange: editableRegionRange,
					},
				],
			} satisfies CodeCompletionResponseParams
		}
	}

	// https://docs.inceptionlabs.ai/capabilities/next-edit
	private buildInceptionNextEditPrompt(params: CodeCompletionRequestParams): {
		editableRegionRange: CursorRange
		prompt: string
	} {
		const fileContent = params.prefix + params.suffix
		const lines = fileContent.split("\n")

		// Calculate editable region (0 lines before, 5 lines after cursor)
		const cursorLine = params.selection.start.line
		const editableRegionStart = Math.max(0, cursorLine)
		const editableRegionEnd = Math.min(lines.length - 1, cursorLine + 5)

		// Build recently viewed code snippets section
		let recentlyViewedSnippets = ""
		let snippets: string[] = []
		if (params.recentlyOpenedFiles && params.recentlyOpenedFiles.length > 0) {
			snippets = params.recentlyOpenedFiles.slice(0, 3).map((file) => {
				return `${INCEPTION_RECENTLY_VIEWED_CODE_SNIPPET_OPEN}\ncode_snippet_file_path: ${file.filepath}\n${file.content}\n${INCEPTION_RECENTLY_VIEWED_CODE_SNIPPET_CLOSE}`
			})
		}
		if (params.pasteboardContent?.length) {
			snippets.push(
				`${INCEPTION_RECENTLY_VIEWED_CODE_SNIPPET_OPEN}\ncode_snippet_file_path: clipboard\n${params.pasteboardContent}\n${INCEPTION_RECENTLY_VIEWED_CODE_SNIPPET_CLOSE}`,
			)
		}
		recentlyViewedSnippets = snippets.join("\n")

		// Build current file content with editable region and cursor
		const beforeRegion = lines.slice(0, editableRegionStart)
		const editableRegion = lines.slice(editableRegionStart, editableRegionEnd + 1)
		const afterRegion = lines.slice(editableRegionEnd + 1)

		// Insert cursor token
		const relativeCursorLine = cursorLine - editableRegionStart
		const cursorChar = params.selection.start.character
		if (relativeCursorLine >= 0 && relativeCursorLine < editableRegion.length) {
			const line = editableRegion[relativeCursorLine]
			const charPos = Math.min(Math.max(0, cursorChar), line.length)
			editableRegion[relativeCursorLine] = line.slice(0, charPos) + INCEPTION_CURSOR + line.slice(charPos)
		}

		const prefix = beforeRegion.join("\n") + (beforeRegion.length > 0 ? "\n" : "")
		const suffix = (afterRegion.length > 0 ? "\n" : "") + afterRegion.join("\n")

		const currentFileContent =
			prefix +
			INCEPTION_CODE_TO_EDIT_OPEN +
			"\n" +
			editableRegion.join("\n") +
			"\n" +
			INCEPTION_CODE_TO_EDIT_CLOSE +
			suffix

		// Build edit diff history
		const editDiffHistory = params.recentEdits || ""

		// Assemble the full prompt
		const prompt = `${INCEPTION_RECENTLY_VIEWED_CODE_SNIPPETS_OPEN}
${recentlyViewedSnippets}
${INCEPTION_RECENTLY_VIEWED_CODE_SNIPPETS_CLOSE}

${INCEPTION_CURRENT_FILE_CONTENT_OPEN}
${currentFileContent}
${INCEPTION_CURRENT_FILE_CONTENT_CLOSE}

${INCEPTION_EDIT_DIFF_HISTORY_OPEN}
${editDiffHistory}
${INCEPTION_EDIT_DIFF_HISTORY_CLOSE}`

		return {
			prompt,
			editableRegionRange: {
				start: {
					line: beforeRegion.length,
					character: 0,
				},
				end: {
					line: beforeRegion.length + editableRegion.length - 1,
					character: editableRegion[editableRegion.length - 1].length,
				},
			},
		}
	}

	private extractCodeFromResponse(response: string): string {
		// Mercury returns code wrapped in markdown code blocks
		// Extract the code between ``` markers
		const codeBlockStart = response.indexOf("```\n")
		const codeBlockEnd = response.lastIndexOf("\n```")

		if (codeBlockStart !== -1 && codeBlockEnd !== -1) {
			return response.slice(codeBlockStart + "```\n".length, codeBlockEnd)
		}

		// If no code blocks found, return as-is
		return response
	}
	private identifyModel(model: Model, models: ProviderModelFullInfo[]): ProviderModel | undefined {
		// OpenAI            ->  OpenRouter
		// mercury           ->  inception/mercury
		const matchedId = `inception/${model.id}`
		const match = models.find((m) => matchedId == m.id)
		if (match) {
			return {
				...match,
				providerId: model.id,
				globalId: match.id,
				max_completion_tokens: match.top_provider.max_completion_tokens,
				supportsChat: true,
				supportsCompletion: model.id === "mercury-coder",
			}
		}
		return undefined
	}
}
