import { APIProvider } from "./sendMessageSchema"

export interface CodeCompletionRequestParams {
	model: string
	provider: APIProvider
	selection: CursorRange
	recentEdits?: string
	pasteboardContent?: string
	recentlyOpenedFiles?: RecentlyOpenedFile[]
	formattingMetadata: FileFormattingMetadata
	prefix: string
	suffix: string
	filepath: string
}

export interface RecentlyOpenedFile {
	filepath: string
	content: string
	lastAccessedAt?: string
}

export interface CodeCompletionResponseParams {
	choices: {
		text: string
		changedRange: CursorRange
	}[]
}

export interface CursorRange {
	start: CursorPosition
	end: CursorPosition
}

export interface CursorPosition {
	/**
	 * @format integer
	 */
	line: number
	/**
	 * @format integer
	 */
	character: number
}

export interface FileFormattingMetadata {
	/**
	 * @format integer
	 */
	tabSize: number
	/**
	 * @format integer
	 */
	indentSize: number
	usesTabsForIndentation: boolean
	uti: string
}
