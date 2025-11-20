import { FileFormattingMetadata, RecentlyOpenedFile } from "@/server/schemas/codeCompletionSchema"
import { Tiktoken, encodingForModel } from "js-tiktoken"

// ============================================================================
// Token Counting
// ============================================================================

let encoding: Tiktoken | null = null

function getEncoding(): Tiktoken {
	if (!encoding) {
		// Use cl100k_base encoding (used by GPT-4, similar token counts to Mistral)
		encoding = encodingForModel("gpt-4")
	}
	return encoding
}

export function countTokens(text: string): number {
	const enc = getEncoding()
	return enc.encode(text).length
}

// ============================================================================
// Token Budget Configuration
// ============================================================================

export interface TokenBudget {
	maxPromptTokens: number
	prefixPercentage: number
	maxSuffixPercentage: number
}

export const DEFAULT_TOKEN_BUDGET: TokenBudget = {
	maxPromptTokens: 1024,
	prefixPercentage: 0.3, // 30% for prefix
	maxSuffixPercentage: 0.2, // 20% for suffix (rest for snippets)
}

// ============================================================================
// Snippet Types
// ============================================================================

export interface CodeSnippet {
	filepath: string
	content: string
	type: "clipboard" | "recentEdit" | "recentFile" | "currentFile"
}

// ============================================================================
// Snippet Formatting
// ============================================================================

/**
 * Get comment syntax for the file type
 */
function getCommentPrefix(uti: string): string {
	// Map UTIs to comment syntax
	const commentMap: Record<string, string> = {
		"public.python-script": "#",
		"public.swift-source": "//",
		"public.c-source": "//",
		"public.c-plus-plus-source": "//",
		"public.objective-c-source": "//",
		"public.java-source": "//",
		"public.javascript-source": "//",
		"public.typescript-source": "//",
		"public.rust-source": "//",
		"public.go-source": "//",
		"public.ruby-script": "#",
		"public.shell-script": "#",
	}

	return commentMap[uti] || "//"
}

/**
 * Get a short relative path for display
 */
function getShortPath(filepath: string, maxSegments = 2): string {
	const parts = filepath.split("/").filter((p) => p.length > 0)
	if (parts.length <= maxSegments) {
		return parts.join("/")
	}
	return parts.slice(-maxSegments).join("/")
}

/**
 * Format snippet content as comments
 */
function formatSnippetAsComment(snippet: CodeSnippet, commentPrefix: string): string {
	const shortPath = getShortPath(snippet.filepath)
	const lines = snippet.content.split("\n")

	// Add path header
	const formattedLines = [`${commentPrefix} Path: ${shortPath}`]

	// Add content lines as comments
	for (const line of lines) {
		if (line.trim().length === 0) {
			formattedLines.push(commentPrefix)
		} else {
			formattedLines.push(`${commentPrefix} ${line}`)
		}
	}

	return formattedLines.join("\n")
}

// ============================================================================
// Snippet Ranking and Filtering
// ============================================================================

/**
 * Extract symbols (identifiers) from code
 */
function getSymbols(text: string): Set<string> {
	// Split on common delimiters to extract identifiers
	const symbolRegex = /[\s.,/#!$%^&*;:{}=\-_`~()[\]]/g
	const symbols = text
		.split(symbolRegex)
		.map((s) => s.trim())
		.filter((s) => s.length > 0)

	return new Set(symbols)
}

/**
 * Calculate Jaccard similarity between two strings based on shared symbols
 */
function calculateSimilarity(textA: string, textB: string): number {
	const setA = getSymbols(textA)
	const setB = getSymbols(textB)

	const union = new Set([...setA, ...setB])
	if (union.size === 0) return 0

	let intersection = 0
	for (const symbol of setA) {
		if (setB.has(symbol)) {
			intersection++
		}
	}

	return intersection / union.size
}

/**
 * Rank snippets by relevance to the code around cursor
 */
function rankSnippets(snippets: CodeSnippet[], contextAroundCursor: string): CodeSnippet[] {
	const scored = snippets.map((snippet) => ({
		snippet,
		score: calculateSimilarity(snippet.content, contextAroundCursor),
	}))

	// Sort by score descending (highest similarity first)
	scored.sort((a, b) => b.score - a.score)

	return scored.map((s) => s.snippet)
}

// ============================================================================
// Context Snippet Selection
// ============================================================================

interface SnippetSelectionResult {
	selectedSnippets: CodeSnippet[]
	tokensUsed: number
}

/**
 * Select snippets that fit within the token budget
 */
function selectSnippetsWithinBudget(
	snippets: CodeSnippet[],
	maxTokens: number,
	commentPrefix: string,
): SnippetSelectionResult {
	const selectedSnippets: CodeSnippet[] = []
	let tokensUsed = 0
	const TOKEN_BUFFER = 10 // Safety buffer per snippet

	for (const snippet of snippets) {
		const formatted = formatSnippetAsComment(snippet, commentPrefix)
		const snippetTokens = countTokens(formatted) + TOKEN_BUFFER

		if (tokensUsed + snippetTokens <= maxTokens) {
			selectedSnippets.push(snippet)
			tokensUsed += snippetTokens
		}
	}

	return { selectedSnippets, tokensUsed }
}

/**
 * Trim file content from the bottom to fit within token limit
 */
function trimContentFromBottom(content: string, maxTokens: number): string {
	const currentTokens = countTokens(content)
	if (currentTokens <= maxTokens) {
		return content
	}

	const lines = content.split("\n")
	let trimmedLines = lines

	while (trimmedLines.length > 0 && countTokens(trimmedLines.join("\n")) > maxTokens) {
		trimmedLines = trimmedLines.slice(0, -1)
	}

	return trimmedLines.join("\n")
}

/**
 * Trim recently opened files to fit within budget
 */
function processRecentlyOpenedFiles(
	files: RecentlyOpenedFile[],
	maxTokens: number,
	commentPrefix: string,
	currentFilepath?: string,
): CodeSnippet[] {
	const MIN_TOKENS_PER_FILE = 125
	const MAX_FILES = 5

	// Filter out current file
	let filteredFiles = files.filter((f) => f.filepath !== currentFilepath)

	// Sort by last accessed (most recent first)
	if (filteredFiles.some((f) => f.lastAccessedAt)) {
		filteredFiles.sort((a, b) => {
			const timeA = a.lastAccessedAt ? new Date(a.lastAccessedAt).getTime() : 0
			const timeB = b.lastAccessedAt ? new Date(b.lastAccessedAt).getTime() : 0
			return timeB - timeA
		})
	}

	// Take top N files
	filteredFiles = filteredFiles.slice(0, MAX_FILES)

	// Calculate how many files can fit with minimum tokens each
	let numFilesThatFit = 0
	let totalTokens = 0

	for (const file of filteredFiles) {
		const fileTokens = countTokens(file.content)
		if (totalTokens + fileTokens < maxTokens) {
			totalTokens += fileTokens
			numFilesThatFit++
		} else {
			break
		}
	}

	// If all files fit, return them as-is
	if (numFilesThatFit >= Math.min(filteredFiles.length, MAX_FILES)) {
		return filteredFiles.slice(0, numFilesThatFit).map((f) => ({
			filepath: f.filepath,
			content: f.content,
			type: "recentFile" as const,
		}))
	}

	// Otherwise, trim files to fit
	const tokensPerFile = Math.max(MIN_TOKENS_PER_FILE, Math.floor(maxTokens / MAX_FILES))
	const trimmedSnippets: CodeSnippet[] = []

	for (const file of filteredFiles.slice(0, MAX_FILES)) {
		const trimmedContent = trimContentFromBottom(file.content, tokensPerFile)
		if (countTokens(trimmedContent) > 0) {
			trimmedSnippets.push({
				filepath: file.filepath,
				content: trimmedContent,
				type: "recentFile",
			})
		}
	}

	return trimmedSnippets
}

// ============================================================================
// Line-based Pruning (for prefix/suffix)
// ============================================================================

/**
 * Prune lines from top (earliest lines) to fit within token limit
 */
export function pruneLinesFromTop(text: string, maxTokens: number): string {
	const lines = text.split("\n")
	const lineTokens = lines.map((line) => countTokens(line))
	let totalTokens = lineTokens.reduce((sum, tokens) => sum + tokens, 0)

	// Account for newline characters
	totalTokens += Math.max(0, lines.length - 1)

	let start = 0

	while (totalTokens > maxTokens && start < lines.length) {
		totalTokens -= lineTokens[start]
		if (lines.length - start > 1) {
			totalTokens-- // Remove newline token
		}
		start++
	}

	return lines.slice(start).join("\n")
}

/**
 * Prune lines from bottom (latest lines) to fit within token limit
 */
export function pruneLinesFromBottom(text: string, maxTokens: number): string {
	const lines = text.split("\n")
	const lineTokens = lines.map((line) => countTokens(line))
	let totalTokens = lineTokens.reduce((sum, tokens) => sum + tokens, 0)

	// Account for newline characters
	totalTokens += Math.max(0, lines.length - 1)

	let end = lines.length

	while (totalTokens > maxTokens && end > 0) {
		end--
		totalTokens -= lineTokens[end]
		if (end > 0) {
			totalTokens-- // Remove newline token
		}
	}

	return lines.slice(0, end).join("\n")
}

// ============================================================================
// Main Request Builder
// ============================================================================

export interface BuildRequestParams {
	prefix: string
	suffix?: string
	pasteboardContent?: string
	recentEdits?: string
	recentlyOpenedFiles?: RecentlyOpenedFile[]
	filepath?: string
	cursorPosition?: { line: number; character: number }
	formattingMetadata: FileFormattingMetadata
	tokenBudget?: TokenBudget
}

export interface BuildRequestResult {
	prompt: string
	suffix?: string
	context: {
		snippetsIncluded: number
		tokensUsed: {
			prefix: number
			suffix: number
			snippets: number
			total: number
		}
	}
}

export function buildRequest(params: BuildRequestParams): BuildRequestResult {
	const budget = params.tokenBudget || DEFAULT_TOKEN_BUDGET
	const commentPrefix = getCommentPrefix(params.formattingMetadata.uti)

	// ========================================================================
	// Step 1: Calculate token budgets for each section
	// ========================================================================

	const maxPrefixTokens = Math.floor(budget.maxPromptTokens * budget.prefixPercentage)
	const maxSuffixTokens = Math.floor(budget.maxPromptTokens * budget.maxSuffixPercentage)
	const maxSnippetTokens = budget.maxPromptTokens - maxPrefixTokens - maxSuffixTokens

	// ========================================================================
	// Step 2: Prune prefix and suffix to fit their budgets
	// ========================================================================

	const prunedPrefix = pruneLinesFromTop(params.prefix, maxPrefixTokens)
	const prunedSuffix = params.suffix ? pruneLinesFromBottom(params.suffix, maxSuffixTokens) : undefined

	const prefixTokens = countTokens(prunedPrefix)
	const suffixTokens = prunedSuffix ? countTokens(prunedSuffix) : 0

	// Calculate remaining tokens for snippets
	const remainingSnippetTokens = maxSnippetTokens

	// ========================================================================
	// Step 3: Gather and rank context snippets
	// ========================================================================

	const allSnippets: CodeSnippet[] = []

	// Add clipboard content
	if (params.pasteboardContent) {
		allSnippets.push({
			filepath: "clipboard",
			content: params.pasteboardContent,
			type: "clipboard",
		})
	}

	// Add recent edits
	if (params.recentEdits) {
		allSnippets.push({
			filepath: params.filepath || "current-file",
			content: params.recentEdits,
			type: "recentEdit",
		})
	}

	// Process recently opened files
	if (params.recentlyOpenedFiles && params.recentlyOpenedFiles.length > 0) {
		const recentFileSnippets = processRecentlyOpenedFiles(
			params.recentlyOpenedFiles,
			remainingSnippetTokens * 0.7, // Allocate 70% of snippet budget to recent files
			commentPrefix,
			params.filepath,
		)
		allSnippets.push(...recentFileSnippets)
	}

	// ========================================================================
	// Step 4: Rank snippets by relevance
	// ========================================================================

	const contextAroundCursor = prunedPrefix.split("\n").slice(-5).join("\n") + (prunedSuffix || "")

	const rankedSnippets = rankSnippets(allSnippets, contextAroundCursor)

	// ========================================================================
	// Step 5: Select snippets within budget
	// ========================================================================

	const { selectedSnippets, tokensUsed: snippetTokensUsed } = selectSnippetsWithinBudget(
		rankedSnippets,
		remainingSnippetTokens,
		commentPrefix,
	)

	// ========================================================================
	// Step 6: Format snippets and build final prompt
	// ========================================================================

	const formattedSnippets = selectedSnippets
		.map((snippet) => formatSnippetAsComment(snippet, commentPrefix))
		.join("\n\n")

	// Add current file path at the end if we have it
	const currentFileComment = params.filepath ? `${commentPrefix} Path: ${getShortPath(params.filepath)}` : ""

	const finalPrefix = [formattedSnippets, currentFileComment, prunedPrefix].filter((s) => s.length > 0).join("\n\n")

	// ========================================================================
	// Step 7: Return result with metadata
	// ========================================================================

	return {
		prompt: finalPrefix,
		suffix: prunedSuffix,
		context: {
			snippetsIncluded: selectedSnippets.length,
			tokensUsed: {
				prefix: prefixTokens,
				suffix: suffixTokens,
				snippets: snippetTokensUsed,
				total: prefixTokens + suffixTokens + snippetTokensUsed,
			},
		},
	}
}

// ============================================================================
// Instruct Mode - Next Edit Style Prompting
// ============================================================================

const EDITABLE_REGION_START_TOKEN = "<|editable_region_start|>"
const EDITABLE_REGION_END_TOKEN = "<|editable_region_end|>"
const CURSOR_TOKEN = "<|cursor|>"

export interface InstructPromptParams {
	prefix: string
	suffix: string
	cursorPosition: { line: number; character: number }
	editableRangeMargin?: { top: number; bottom: number }
	recentEdits?: string
	contextSnippets?: CodeSnippet[]
	filepath?: string
	commentPrefix: string
}

export interface InstructPromptResult {
	systemPrompt: string
	userPrompt: string
	editableRegionStart: number
	editableRegionEnd: number
}

/**
 * Build an instruct-style prompt for next-edit prediction
 * Similar to Continue's NextEdit feature but using chat completion
 */
export function buildInstructPrompt(params: InstructPromptParams): InstructPromptResult {
	const { prefix, suffix, cursorPosition, editableRangeMargin = { top: 0, bottom: 5 }, commentPrefix } = params
	const fileContent = prefix + suffix

	const lines = fileContent.split("\n")

	// Calculate editable region
	const editableRegionStart = Math.max(0, cursorPosition.line - editableRangeMargin.top)
	const editableRegionEnd = Math.min(lines.length - 1, cursorPosition.line + editableRangeMargin.bottom)

	// Build context snippets section
	let contextSection = ""
	if (params.contextSnippets && params.contextSnippets.length > 0) {
		const snippetTexts = params.contextSnippets.map((snippet) => {
			const shortPath = getShortPath(snippet.filepath)
			return `${commentPrefix} File: ${shortPath}\n${snippet.content}`
		})
		contextSection = `### Context\n\n${snippetTexts.join("\n\n")}\n\n`
	}

	// Build recent edits section
	let editsSection = ""
	if (params.recentEdits) {
		editsSection = `### Recent Edits\n\n${params.recentEdits}\n\n`
	}

	// Build the file content with editable region markers
	const beforeRegion = lines.slice(0, editableRegionStart)
	const editableRegion = lines.slice(editableRegionStart, editableRegionEnd + 1)
	const afterRegion = lines.slice(editableRegionEnd + 1)

	// Insert cursor token into the editable region
	const relativeCursorLine = cursorPosition.line - editableRegionStart
	if (relativeCursorLine >= 0 && relativeCursorLine < editableRegion.length) {
		const line = editableRegion[relativeCursorLine]
		const charPos = Math.min(Math.max(0, cursorPosition.character), line.length)
		editableRegion[relativeCursorLine] = line.slice(0, charPos) + CURSOR_TOKEN + line.slice(charPos)
	}

	const fileSection = `### Current File\n\n${commentPrefix} Path: ${params.filepath || "untitled"}\n\n${beforeRegion.join("\n")}\n${EDITABLE_REGION_START_TOKEN}\n${editableRegion.join("\n")}\n${EDITABLE_REGION_END_TOKEN}\n${afterRegion.join("\n")}`

	// System prompt similar to Continue's Instinct model
	const systemPrompt = `You are an intelligent code completion assistant. Your role is to predict and complete the next edit the developer will make within the editable region marked by ${EDITABLE_REGION_START_TOKEN} and ${EDITABLE_REGION_END_TOKEN}.

The ${CURSOR_TOKEN} marker indicates where the developer's cursor is currently located. The developer may have stopped in the middle of typing.

Your task:
1. Review the context, recent edits, and current code
2. Determine if changes are needed in the editable region
3. If changes are needed, provide the complete revised code for the editable region
4. Maintain consistent indentation and formatting
5. Do not undo recent changes unless there are obvious errors

Output only the revised code that should replace the content between the markers. Do not include the markers themselves in your output.`

	// User prompt
	const userPrompt = `${contextSection}${editsSection}${fileSection}

Predict and complete the changes for the editable region. Output only the revised code, without the markers.`

	return {
		systemPrompt,
		userPrompt,
		editableRegionStart,
		editableRegionEnd,
	}
}

// ============================================================================
// Response Processing
// ============================================================================

export interface ProcessCompletionResponse {
	fullFileContent: string
	changedRange?: {
		start: { line: number; character: number }
		end: { line: number; character: number }
	}
}

/**
 * Process instruct/next-edit completion and return full file content
 */
export function processInstructCompletion(
	prefix: string,
	suffix: string,
	editableRegionStart: number,
	editableRegionEnd: number,
	completion: string,
): ProcessCompletionResponse {
	const fileContent = prefix + suffix
	const lines = fileContent.split("\n")
	const newRegionLines = completion.split("\n")

	// Replace the editable region with the new content
	const before = lines.slice(0, editableRegionStart)
	const after = lines.slice(editableRegionEnd + 1)

	const newLines = [...before, ...newRegionLines, ...after]

	return {
		fullFileContent: newLines.join("\n"),
		changedRange: {
			start: { line: editableRegionStart, character: 0 },
			end: {
				line: editableRegionStart + newRegionLines.length - 1,
				character: newRegionLines[newRegionLines.length - 1].length,
			},
		},
	}
}
