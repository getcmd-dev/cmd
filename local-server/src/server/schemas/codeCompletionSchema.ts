import { APIProvider } from "./sendMessageSchema"

export interface CodeCompletionRequestParams {
	model: string
	provider: APIProvider
	selection: CursorRange
	recentEdits?: string
	pasteboardContent?: string
	formattingMetadata: FileFormattingMetadata
	prefix: string
	suffix?: string
}

export interface CodeCompletionResponseParams {
	choices: {
		text: string
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
