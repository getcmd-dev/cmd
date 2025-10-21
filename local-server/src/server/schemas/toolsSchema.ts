// @generates: ./app/modules/foundations/ToolTypesFoundation/Sources/tools.generated.swift
// @schema-name: ToolsSchema

export type InternalToolInputSchemas =
	| LSToolInput
	| AskFollowUpToolInput
	| EditFilesToolInput
	| ExecuteCommandToolInput
	| ReadFileToolInput
	| SearchFilesToolInput
	| GlobToolInput
	| TodoWriteToolInput
	| WebFetchToolInput
	| WebSearchToolInput

export type InternalToolOutputSchemas =
	| LSToolOutput
	| AskFollowUpToolOutput
	| EditFilesToolOutput
	| ExecuteCommandToolOutput
	| ReadFileToolOutput
	| SearchFilesToolOutput
	| GlobToolOutput
	| TodoWriteToolOutput
	| WebFetchToolOutput
	| WebSearchToolOutput

// LSTool (list_files)
export type LSToolInput = {
	type: "list_files_input"
	path: string
	recursive?: boolean
}
export type LSToolOutput = {
	type: "list_files_output"
	files: LSToolOutput_File[]
	hasMore: boolean
}
export type LSToolOutput_File = {
	path: string
	attr?: string
	size?: string
}

// AskFollowUpTool (ask_followup)
export type AskFollowUpToolInput = {
	type: "ask_followup_input"
	question: string
	followUp: string[]
}
export type AskFollowUpToolOutput = {
	type: "ask_followup_output"
	response: string
}

// EditFilesTool (edit_file)
export type EditFilesToolInput = {
	type: "edit_files_input"
	files: EditFilesToolInput_FileChange[]
}
export type EditFilesToolInput_FileChange = {
	path: string
	isNewFile?: boolean
	changes: EditFilesToolInput_Change[]
}
export type EditFilesToolInput_Change = {
	search: string
	replace: string
}
export type EditFilesToolOutput = {
	type: "edit_files_output"
	result: string
}

// ExecuteCommandTool (bash)
export type ExecuteCommandToolInput = {
	type: "execute_command_input"
	command: string
	cwd?: string
	canModifySourceFiles: boolean
	canModifyDerivedFiles: boolean
}
export type ExecuteCommandToolOutput = {
	type: "execute_command_output"
	output?: string
	/**
	 * @format integer
	 */
	exitCode: number
}

// ReadFileTool (read_file)
export type ReadFileToolInput = {
	type: "read_file_input"
	path: string
	lineRange?: ReadFileToolInput_Range
}
export type ReadFileToolInput_Range = {
	/**
	 * @format integer
	 */
	start: number
	/**
	 * @format integer
	 */
	end: number
}
export type ReadFileToolOutput = {
	type: "read_file_output"
	content: string
	uri?: string
}

// SearchFilesTool (search)
export type SearchFilesToolInput = {
	type: "search_files_input"
	directoryPath?: string
	regex: string
	filePattern?: string
}
export type SearchFilesToolOutput = {
	type: "search_files_output"
	outputForLLm: string
	results: SearchFileResult[]
	// rootPath?: string
	hasMore: boolean
}
export type SearchFileResult = {
	path: string
	searchResults: SearchResult[]
}
export type SearchResult = {
	/**
	 * @format integer
	 */
	line: number
	text: string
	isMatch: boolean
}

// ClaudeCodeGlobTool (glob)
export type GlobToolInput = {
	type: "glob_input"
	pattern: string
	path?: string
}
export type GlobToolOutput = {
	type: "glob_output"
	files: string[]
}

// TodoWriteTool (update_plan)
export type TodoWriteToolInput = {
	type: "todo_write_input"
	todos: TodoWriteToolInput_TodoItem[]
}
export type TodoWriteToolInput_TodoItem = {
	content: string
	status: string
}
export type TodoWriteToolOutput = {
	type: "todo_write_output"
	// success: boolean
	message: string
}

// WebFetchTool (web_fetch)
export type WebFetchToolInput = {
	type: "web_fetch_input"
	url: string
	prompt: string
}
export type WebFetchToolOutput = {
	type: "web_fetch_output"
	result: string
}

// WebSearchTool (web_search)
export type WebSearchToolInput = {
	type: "web_search_input"
	query: string
	allowed_domains?: string[]
	blocked_domains?: string[]
}
export type WebSearchToolOutput = {
	type: "web_search_output"
	links: WebSearchToolOutput_SearchResult[]
	content: string
}
export type WebSearchToolOutput_SearchResult = {
	title: string
	url: string
}

// ACP
