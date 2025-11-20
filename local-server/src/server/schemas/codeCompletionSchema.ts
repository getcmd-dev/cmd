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
		newContent: string
		changedRange?: {
			start: CursorPosition
			end: CursorPosition
		}
	}[]
}

export interface CursorRange {
	start: CursorPosition
	end: CursorPosition
}

export interface CursorPosition {
	line: number
	character: number
}

export interface FileFormattingMetadata {
	tabSize: number
	indentSize: number
	usesTabsForIndentation: boolean
	uti: string
}
