import { logError, logInfo } from "@/logger"
import { SessionNotification } from "@agentclientprotocol/sdk"

import {
	ToolInputSchemas,
	BashInput,
	FileEditInput,
	FileReadInput,
	FileWriteInput,
	GlobInput,
	GrepInput,
	TodoWriteInput,
	WebFetchInput,
	WebSearchInput,
} from "@anthropic-ai/claude-agent-sdk/sdk-tools"

import {
	ToolOutputSchemas,
	BashOutput,
	EditOutput,
	ReadOutput,
	WriteOutput,
	GlobOutput,
	GrepOutput,
	WebFetchOutput,
	WebSearchOutput,
	TodoWriteOutput,
} from "./types"
import {
	EditFilesToolInput,
	EditFilesToolOutput,
	ExecuteCommandToolInput,
	ExecuteCommandToolOutput,
	GlobToolInput,
	GlobToolOutput,
	InterlalToolOutputSchemas,
	ReadFileToolInput,
	ReadFileToolOutput,
	SearchFilesToolInput,
	SearchFilesToolOutput,
	SearchResult,
	TodoWriteToolInput,
	TodoWriteToolOutput,
	WebFetchToolInput,
	WebFetchToolOutput,
	WebSearchToolInput,
	WebSearchToolOutput,
} from "@/server/schemas/toolsSchema"

const toolNameMapping: { [k: string]: string } = {
	Glob: "glob",
	Read: "read_file",
	TodoWrite: "update_plan",
	WebFetch: "web_fetch",
	WebSearch: "web_search",
	Edit: "edit_file",
	MultiEdit: "edit_file",
	Write: "edit_file",
	Bash: "bash",
	LS: "list_files",
	Grep: "search",
}

export async function* withParsedToolCalls(
	stream: AsyncIterable<SessionNotification>,
): AsyncIterable<SessionNotification> {
	for await (const event of stream) {
		if (event.update.sessionUpdate === "tool_call") {
			const toolName = event.update._meta?.toolName as string | undefined
			if (typeof toolName !== "string") {
				logError(`Tool call without tool name: ${JSON.stringify(event.update, null, 2)}`)
				yield event
				continue
			}
			const input = event.update.rawInput as ToolInputSchemas | undefined
			if (!input) {
				logError(`Tool call without input: ${JSON.stringify(event.update, null, 2)}`)
				yield event
				continue
			}
			yield {
				...event,
				update: {
					...event.update,
					_meta: {
						...event.update._meta,
						toolName: toolNameMapping[toolName] || toolName,
						input: mapToolInput(toolName, input),
					},
				},
			}
		} else if (event.update.sessionUpdate === "tool_call_update") {
			if (event.update.status === "completed") {
				const toolName = event.update._meta?.toolName as string | undefined
				if (typeof toolName !== "string") {
					logError(`Tool call without tool name: ${JSON.stringify(event.update, null, 2)}`)
					yield event
					continue
				}
				const output = event.update._meta?.jsonOutput as ToolOutputSchemas | undefined
				if (!output) {
					logError(`Tool call without output: ${JSON.stringify(event.update, null, 2)}`)
					yield event
					continue
				}
				yield {
					...event,
					update: {
						...event.update,
						_meta: {
							...event.update._meta,
							toolName: toolNameMapping[toolName] || toolName,
							// input: mapToolInput(toolName, input),
							output: mapToolOutput(toolName, output),
						},
					},
				}
			} else {
				yield event
			}
		} else {
			yield event
		}
	}
}

const mapToolInput = (toolName: string, input: ToolInputSchemas): ToolInputSchemas | undefined => {
	switch (toolName) {
		case "Bash": {
			const i = input as BashInput
			return {
				type: "execute_command_input",
				command: i.command,
				canModifySourceFiles: true, // Default to true, which is safer, when the information is not provided
				canModifyDerivedFiles: true, // Default to true, which is safer, when the information is not provided
			} satisfies ExecuteCommandToolInput
		}
		case "Edit": {
			const i = input as FileEditInput
			return {
				type: "edit_files_input",
				files: [
					{
						path: i.file_path,
						changes: [
							{
								search: i.old_string,
								replace: i.new_string,
							},
						],
					},
				],
			} satisfies EditFilesToolInput
		}
		case "Read": {
			const i = input as FileReadInput
			return {
				type: "read_file_input",
				path: i.file_path,
				lineRange: i.offset && i.limit ? { start: i.offset, end: i.offset + i.limit } : undefined,
			} satisfies ReadFileToolInput
		}
		case "Write": {
			const i = input as FileWriteInput
			return {
				type: "edit_files_input",
				files: [
					{
						path: i.file_path,
						changes: [
							{
								search: "",
								replace: i.content,
							},
						],
						isNewFile: true,
					},
				],
			} satisfies EditFilesToolInput
		}
		case "Glob": {
			const i = input as GlobInput
			return {
				type: "glob_input",
				pattern: i.pattern,
				path: i.path,
			} satisfies GlobToolInput
		}
		case "Grep": {
			const i = input as GrepInput
			return {
				type: "search_files_input",
				directoryPath: i.path,
				regex: i.pattern,
				filePattern: i.pattern,
			} satisfies SearchFilesToolInput
		}
		case "WebFetch": {
			const i = input as WebFetchInput
			return {
				type: "web_fetch_input",
				url: i.url,
				prompt: i.prompt,
			} satisfies WebFetchToolInput
		}
		case "WebSearch": {
			const i = input as WebSearchInput
			return {
				type: "web_search_input",
				query: i.query,
				allowed_domains: i.allowed_domains,
				blocked_domains: i.blocked_domains,
			} satisfies WebSearchToolInput
		}
		case "TodoWrite": {
			const i = input as TodoWriteInput
			return {
				type: "todo_write_input",
				todos: i.todos.map((todo) => ({
					content: todo.content,
					status: todo.status,
				})),
			} satisfies TodoWriteToolInput
		}

		case "Task":
		case "BashOutput":
		case "KillBash":
		case "NotebookEdit":
		case "ExitPlanMode":
		case "ListMcpResources":
		case "ReadMcpResource":
			break
	}
	return undefined
}

const mapToolOutput = (toolName: string, output: ToolOutputSchemas): InterlalToolOutputSchemas | undefined => {
	switch (toolName) {
		case "Bash": {
			const o = output as BashOutput
			return {
				type: "execute_command_output",
				exitCode: o.exitCode,
				output: o.output,
			} satisfies ExecuteCommandToolOutput
		}
		case "Edit": {
			const o = output as EditOutput
			return {
				// TODO: improve this result format
				type: "edit_files_output",
				result: o.message,
			} satisfies EditFilesToolOutput
		}
		case "Read": {
			const o = output as ReadOutput
			if ("content" in o) {
				return {
					type: "read_file_output",
					content: o.content,
				} satisfies ReadFileToolOutput
			} else {
				return undefined
			}
		}
		case "Write": {
			const o = output as WriteOutput
			return {
				type: "edit_files_output",
				result: o.message,
			} satisfies EditFilesToolOutput
		}
		case "Glob": {
			const o = output as GlobOutput
			return {
				type: "glob_output",
				files: o.matches, // TODO: look into this conversion
			} satisfies GlobToolOutput
		}
		case "Grep": {
			const o = output as GrepOutput
			if ("total_matches" in o) {
				// GrepContentOutput
				const resultsByFile = o.matches.reduce(
					(acc, match) => {
						acc[match.file] = acc[match.file] || []
						// TODO: add before_context and after_context
						acc[match.file].push({
							line: match.line_number ?? 0,
							text: match.line,
							isMatch: true,
						})
						return acc
					},
					{} as { [key: string]: SearchResult[] },
				)
				const results = Object.entries(resultsByFile).map(([path, results]) => ({
					path: path,
					searchResults: results,
				}))
				return {
					type: "search_files_output",
					outputForLLm: results
						.map(
							(result) =>
								result.path +
								":\n" +
								result.searchResults.map((result) => `L${result.line}: ${result.text}`).join("\n"),
						)
						.join("\n"),
					results,
					hasMore: false,
				} satisfies SearchFilesToolOutput
			} else if ("count" in o) {
				// GrepFilesOutput
				return {
					type: "search_files_output",
					outputForLLm: `${o.count} matches in\n${o.files.join("\n")}`,
					results: [],
					hasMore: false,
				} satisfies SearchFilesToolOutput
			} else {
				// GrepCountOutput
				return {
					type: "search_files_output",
					outputForLLm: o.counts
						.map((countsByFile) => `${countsByFile.file}: ${countsByFile.count} matches`)
						.join("\n"),
					results: [],
					hasMore: false,
				} satisfies SearchFilesToolOutput
			}
		}
		case "WebFetch": {
			const o = output as WebFetchOutput
			return {
				type: "web_fetch_output",
				result: o.response,
			} satisfies WebFetchToolOutput
		}
		case "WebSearch": {
			const o = output as WebSearchOutput
			return {
				type: "web_search_output",
				links: o.results.map((result) => ({
					title: result.title,
					url: result.url,
				})),
				content: o.results.map((result) => result.snippet).join("\n"),
			} satisfies WebSearchToolOutput
		}
		case "TodoWrite": {
			const o = output as TodoWriteOutput
			return {
				type: "todo_write_output",
				message: o.message,
			} satisfies TodoWriteToolOutput
		}

		case "Task":
		case "BashOutput":
		case "KillBash":
		case "NotebookEdit":
		case "ExitPlanMode":
		case "ListMcpResources":
		case "ReadMcpResource":
			break
	}
	return undefined
}
