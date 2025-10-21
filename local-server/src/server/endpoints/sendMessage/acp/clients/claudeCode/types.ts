// Copied from https://docs.claude.com/en/api/agent-sdk/typescript#tool-output-types
// unfortunately, those types don't seem to be part of the sdk.

export type ToolOutputSchemas =
	| TaskOutput
	| BashOutput
	| BashOutputToolOutput
	| EditOutput
	| ReadOutput
	| WriteOutput
	| GlobOutput
	| GrepOutput
	| KillBashOutput
	| NotebookEditOutput
	| WebFetchOutput
	| WebSearchOutput
	| TodoWriteOutput
	| ExitPlanModeOutput
	| ListMcpResourcesOutput
	| ReadMcpResourceOutput

export interface TaskOutput {
	/**
	 * Final result message from the subagent
	 */
	result: string
	/**
	 * Token usage statistics
	 */
	usage?: {
		input_tokens: number
		output_tokens: number
		cache_creation_input_tokens?: number
		cache_read_input_tokens?: number
	}
	/**
	 * Total cost in USD
	 */
	total_cost_usd?: number
	/**
	 * Execution duration in milliseconds
	 */
	duration_ms?: number
}

export interface BashOutput {
	/**
	 * Combined stdout and stderr output
	 */
	output: string
	/**
	 * Exit code of the command
	 */
	exitCode: number
	/**
	 * Whether the command was killed due to timeout
	 */
	killed?: boolean
	/**
	 * Shell ID for background processes
	 */
	shellId?: string
}

export interface BashOutputToolOutput {
	/**
	 * New output since last check
	 */
	output: string
	/**
	 * Current shell status
	 */
	status: "running" | "completed" | "failed"
	/**
	 * Exit code (when completed)
	 */
	exitCode?: number
}

export interface EditOutput {
	/**
	 * Confirmation message
	 */
	message: string
	/**
	 * Number of replacements made
	 */
	replacements: number
	/**
	 * File path that was edited
	 */
	file_path: string
}

export type ReadOutput = TextFileOutput | ImageFileOutput | PDFFileOutput | NotebookFileOutput

export interface TextFileOutput {
	/**
	 * File contents with line numbers
	 */
	content: string
	/**
	 * Total number of lines in file
	 */
	total_lines: number
	/**
	 * Lines actually returned
	 */
	lines_returned: number
}

export interface ImageFileOutput {
	/**
	 * Base64 encoded image data
	 */
	image: string
	/**
	 * Image MIME type
	 */
	mime_type: string
	/**
	 * File size in bytes
	 */
	file_size: number
}

export interface PDFFileOutput {
	/**
	 * Array of page contents
	 */
	pages: Array<{
		page_number: number
		text?: string
		images?: Array<{
			image: string
			mime_type: string
		}>
	}>
	/**
	 * Total number of pages
	 */
	total_pages: number
}

export interface NotebookFileOutput {
	/**
	 * Jupyter notebook cells
	 */
	cells: Array<{
		cell_type: "code" | "markdown"
		source: string
		outputs?: unknown[]
		execution_count?: number
	}>
	/**
	 * Notebook metadata
	 */
	metadata?: Record<string, unknown>
}

export interface WriteOutput {
	/**
	 * Success message
	 */
	message: string
	/**
	 * Number of bytes written
	 */
	bytes_written: number
	/**
	 * File path that was written
	 */
	file_path: string
}

export interface GlobOutput {
	/**
	 * Array of matching file paths
	 */
	matches: string[]
	/**
	 * Number of matches found
	 */
	count: number
	/**
	 * Search directory used
	 */
	search_path: string
}

export type GrepOutput = GrepContentOutput | GrepFilesOutput | GrepCountOutput

export interface GrepContentOutput {
	/**
	 * Matching lines with context
	 */
	matches: Array<{
		file: string
		line_number?: number
		line: string
		before_context?: string[]
		after_context?: string[]
	}>
	/**
	 * Total number of matches
	 */
	total_matches: number
}

export interface GrepFilesOutput {
	/**
	 * Files containing matches
	 */
	files: string[]
	/**
	 * Number of files with matches
	 */
	count: number
}

export interface GrepCountOutput {
	/**
	 * Match counts per file
	 */
	counts: Array<{
		file: string
		count: number
	}>
	/**
	 * Total matches across all files
	 */
	total: number
}

export interface KillBashOutput {
	/**
	 * Success message
	 */
	message: string
	/**
	 * ID of the killed shell
	 */
	shell_id: string
}

export interface NotebookEditOutput {
	/**
	 * Success message
	 */
	message: string
	/**
	 * Type of edit performed
	 */
	edit_type: "replaced" | "inserted" | "deleted"
	/**
	 * Cell ID that was affected
	 */
	cell_id?: string
	/**
	 * Total cells in notebook after edit
	 */
	total_cells: number
}

// Note: empirically, the returned object significantly differs from the SDK type:
// https://docs.claude.com/en/api/agent-sdk/typescript#webfetch-2
export interface WebFetchOutput {
	/**
	 * AI model's response to the prompt
	 */
	result: string
	/**
	 * URL that was fetched
	 */
	url: string
	/**
	 * Final URL after redirects
	 */
	final_url?: string
	/**
	 * HTTP status code
	 */
	code?: number
}

// Note: empirically, the returned object significantly differs from the SDK type:
// https://docs.claude.com/en/api/agent-sdk/typescript#websearch-2
export interface WebSearchOutput {
	/**
	 * Search results
	 */
	results: Array<
		| {
				tool_use_id: string
				content: Array<{
					title: string
					url: string
					/**
					 * Additional metadata if available
					 */
					metadata?: Record<string, unknown>
				}>
		  }
		| string
	>
	durationSeconds: number
	/**
	 * The query that was searched
	 */
	query: string
}

export interface TodoWriteOutput {
	/**
	 * Success message
	 */
	message: string
	/**
	 * Current todo statistics
	 */
	stats: {
		total: number
		pending: number
		in_progress: number
		completed: number
	}
}

export interface ExitPlanModeOutput {
	/**
	 * Confirmation message
	 */
	message: string
	/**
	 * Whether user approved the plan
	 */
	approved?: boolean
}

export interface ListMcpResourcesOutput {
	/**
	 * Available resources
	 */
	resources: Array<{
		uri: string
		name: string
		description?: string
		mimeType?: string
		server: string
	}>
	/**
	 * Total number of resources
	 */
	total: number
}

export interface ReadMcpResourceOutput {
	/**
	 * Resource contents
	 */
	contents: Array<{
		uri: string
		mimeType?: string
		text?: string
		blob?: string
	}>
	/**
	 * Server that provided the resource
	 */
	server: string
}
