// Copied from https://github.com/RooVetGit/Roo-Code/blob/9fadd3dbe20011cde2c3a6e1d9cacb479296129e/src/services/ripgrep/index.ts

import * as childProcess from "child_process"
import * as path from "path"
import * as readline from "readline"
import { SearchFilesToolOutput, SearchFileResult as SearchFileResultSchema } from "../../../schemas/toolsSchema"
import { logError } from "../../../../logger"
import { UserFacingError } from "../../../errors"

/*
This file provides functionality to perform regex searches on files using ripgrep.
Inspired by: https://github.com/DiscreteTom/vscode-ripgrep-utils

Key components:
1. getBinPath: Locates the ripgrep binary within the VSCode installation.
2. execRipgrep: Executes the ripgrep command and returns the output.
3. regexSearchFiles: The main function that performs regex searches on files.
   - Parameters:
     * cwd: The current working directory (for relative path calculation)
     * directoryPath: The directory to search in
     * regex: The regular expression to search for (Rust regex syntax)
     * filePattern: Optional glob pattern to filter files (default: '*')
   - Returns: A formatted string containing search results with context

The search results include:
- Relative file paths
- 2 lines of context before and after each match
- Matches formatted with pipe characters for easy reading

Usage example:
const results = await regexSearchFiles('/path/to/cwd', '/path/to/search', 'TODO:', '*.ts');

rel/path/to/app.ts
│----
│function processData(data: any) {
│  // Some processing logic here
│  // TODO: Implement error handling
│  return processedData;
│}
│----

rel/path/to/helper.ts
│----
│  let result = 0;
│  for (let i = 0; i < input; i++) {
│    // TODO: Optimize this function for performance
│    result += Math.pow(i, 2);
│  }
│----
*/

interface SearchFileResult {
	file: string
	searchResults: SearchResult[]
}

interface SearchResult {
	lines: SearchLineResult[]
}

interface SearchLineResult {
	line: number
	text: string
	isMatch: boolean
	column?: number
}
// Constants
const MAX_RESULTS = 300
const MAX_LINE_LENGTH = 500

/**
 * Truncates a line if it exceeds the maximum length
 * @param line The line to truncate
 * @param maxLength The maximum allowed length (defaults to MAX_LINE_LENGTH)
 * @returns The truncated line, or the original line if it's shorter than maxLength
 */
export function truncateLine(line: string, maxLength: number = MAX_LINE_LENGTH): string {
	return line.length > maxLength ? line.substring(0, maxLength) + " [truncated...]" : line
}

async function execRipgrep(bin: string, args: string[]): Promise<string> {
	return new Promise((resolve, reject) => {
		const rgProcess = childProcess.spawn(bin, args)
		// cross-platform alternative to head, which is ripgrep author's recommendation for limiting output.
		const rl = readline.createInterface({
			input: rgProcess.stdout,
			crlfDelay: Infinity, // treat \r\n as a single line break even if it's split across chunks. This ensures consistent behavior across different operating systems.
		})

		let output = ""
		let lineCount = 0
		const maxLines = MAX_RESULTS * 5 // limiting ripgrep output with max lines since there's no other way to limit results. it's okay that we're outputting as json, since we're parsing it line by line and ignore anything that's not part of a match. This assumes each result is at most 5 lines.

		rl.on("line", (line) => {
			if (lineCount < maxLines) {
				output += line + "\n"
				lineCount++
			} else {
				rl.close()
				rgProcess.kill()
			}
		})

		let errorOutput = ""
		rgProcess.stderr.on("data", (data) => {
			errorOutput += data.toString()
		})
		rl.on("close", () => {
			if (errorOutput) {
				reject(new Error(`ripgrep process error: ${errorOutput}`))
			} else {
				resolve(output)
			}
		})
		rgProcess.on("error", (error) => {
			reject(new Error(`ripgrep process error: ${error.message}`))
		})
	})
}

export async function regexSearchFiles({
	cwd,
	directoryPath,
	regex,
	filePattern,
}: {
	cwd: string
	directoryPath: string
	regex: string
	filePattern?: string
}): Promise<SearchFilesToolOutput> {
	const args = ["--json", "-e", regex, "--glob", filePattern || "*", "--context", "1", directoryPath]
	let output: string
	try {
		const rgPath = path.join(__dirname, "./", "rg-14.1.1")
		output = await execRipgrep(rgPath, args)
	} catch (error) {
		const rethrown = new UserFacingError({
			message: `Error executing ripgrep: ${error}`,
			underlyingError: error as Error,
		})
		logError(rethrown)
		throw rethrown
	}

	const results: SearchFileResult[] = []
	let currentFile: SearchFileResult | null = null

	output.split("\n").forEach((line) => {
		if (line) {
			try {
				const parsed = JSON.parse(line)
				if (parsed.type === "begin") {
					currentFile = {
						file: parsed.data.path.text.toString(),
						searchResults: [],
					}
				} else if (parsed.type === "end") {
					// Reset the current result when a new file is encountered
					results.push(currentFile as SearchFileResult)
					currentFile = null
				} else if ((parsed.type === "match" || parsed.type === "context") && currentFile) {
					const line: {
						line: number
						text: string
						isMatch: boolean
						absolute_offset?: number
						submatches?: {
							match: { text: string }
							start: number
							end: number
						}[]
					} = {
						line: parsed.data.line_number,
						text: truncateLine(parsed.data.lines.text),
						isMatch: parsed.type === "match",
						...(parsed.type === "match" && {
							absolute_offset: parsed.data.absolute_offset,
							submatches: parsed.data.submatches,
						}),
					}

					const lastResult = currentFile.searchResults[currentFile.searchResults.length - 1]
					if (lastResult?.lines.length > 0) {
						const lastLine = lastResult.lines[lastResult.lines.length - 1]

						// If this line is contiguous with the last result, add to it
						if (parsed.data.line_number <= lastLine.line + 1) {
							lastResult.lines.push(line)
						} else {
							// Otherwise create a new result
							currentFile.searchResults.push({
								lines: [line],
							})
						}
					} else {
						// First line in file
						currentFile.searchResults.push({
							lines: [line],
						})
					}
				}
			} catch (error) {
				console.error("Error parsing ripgrep output:", error)
			}
		}
	})

	return formatResults(
		results.filter((result) => result.file.includes(".swift")),
		cwd,
	)
}

function formatResults(fileResults: SearchFileResult[], cwd: string): SearchFilesToolOutput {
	const groupedResults: { [key: string]: SearchResult[] } = {}
	const parsedResults: {
		[key: string]: SearchFileResultSchema
	} = {}

	const totalResults = fileResults.reduce((sum, file) => sum + file.searchResults.length, 0)
	let output = ""
	if (totalResults >= MAX_RESULTS) {
		output += `Showing first ${MAX_RESULTS} of ${MAX_RESULTS}+ results. Use a more specific search if necessary.\n\n`
	} else {
		output += `Found ${totalResults === 1 ? "1 result" : `${totalResults.toLocaleString()} results`}.\n\n`
	}

	// Group results by file name
	fileResults.slice(0, MAX_RESULTS).forEach((file) => {
		const relativeFilePath = path.relative(cwd, file.file)
		if (!groupedResults[relativeFilePath]) {
			groupedResults[relativeFilePath] = []
			groupedResults[relativeFilePath].push(...file.searchResults)
			parsedResults[relativeFilePath] = {
				path: path.resolve(cwd, file.file),
				searchResults: file.searchResults.flatMap((result) => result.lines),
			}
		} else {
			parsedResults[relativeFilePath].searchResults.push(...file.searchResults.flatMap((result) => result.lines))
		}
	})

	for (const [filePath, fileResults] of Object.entries(groupedResults)) {
		output += `# ${filePath.toPosix()}\n`

		fileResults.forEach((result) => {
			// Only show results with at least one line
			if (result.lines.length > 0) {
				// Show all lines in the result
				result.lines.forEach((line) => {
					const lineNumber = String(line.line).padStart(3, " ")
					output += `${lineNumber} | ${line.text.trimEnd()}\n`
				})
				output += "----\n"
			}
		})

		output += "\n"
	}

	return {
		type: "search_files_output",
		outputForLLm: output.trim(),
		results: Object.values(parsedResults),
		hasMore: totalResults >= MAX_RESULTS,
	}
}
