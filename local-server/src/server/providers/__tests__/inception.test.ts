import { buildInceptionNextEditPrompt, INCEPTION_CONSTANTS } from "../inception"
import { CodeCompletionRequestParams } from "../../endpoints/codeCompletion/helpers"

describe("buildInceptionNextEditPrompt", () => {
	const baseParams: CodeCompletionRequestParams = {
		prefix: "",
		suffix: "",
		filepath: "test.ts",
		selection: { start: { line: 0, character: 0 }, end: { line: 0, character: 0 } },
		formattingMetadata: {
			tabSize: 2,
			indentSize: 2,
			usesTabsForIndentation: false,
			uti: "public.typescript-source",
		},
	}

	it("should match snapshot for basic single-line file", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "function test() { ",
			suffix: " }",
			selection: { start: { line: 0, character: 18 }, end: { line: 0, character: 18 } },
		}

		const result = buildInceptionNextEditPrompt(params)

		expect(result).toMatchSnapshot()
	})

	it("should match snapshot with clipboard content", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "const value = ",
			suffix: "",
			selection: { start: { line: 0, character: 14 }, end: { line: 0, character: 14 } },
			pasteboardContent: "42",
		}

		const result = buildInceptionNextEditPrompt(params)

		expect(result).toMatchSnapshot()
	})

	it("should match snapshot with recently opened files", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "import ",
			suffix: "\n\nexport function main() {}",
			selection: { start: { line: 0, character: 7 }, end: { line: 0, character: 7 } },
			recentlyOpenedFiles: [
				{
					filepath: "/workspace/src/helper.ts",
					content: "export function help() {\n  return 'help'\n}",
				},
				{
					filepath: "/workspace/src/utils.ts",
					content: "export const PI = 3.14",
				},
			],
		}

		const result = buildInceptionNextEditPrompt(params)

		expect(result).toMatchSnapshot()
	})

	it("should match snapshot with recent edits", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "function calculate() {\n  ",
			suffix: "\n}",
			selection: { start: { line: 1, character: 2 }, end: { line: 1, character: 2 } },
			recentEdits: `diff --git a/test.ts b/test.ts
--- a/test.ts
+++ b/test.ts
@@ -1,3 +1,3 @@
-const x = 1
+const x = 2`,
		}

		const result = buildInceptionNextEditPrompt(params)

		expect(result).toMatchSnapshot()
	})

	it("should match snapshot for multi-line file with cursor in middle", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "function example() {\n  const x = 1\n  ",
			suffix: "\n  return x\n}",
			selection: { start: { line: 2, character: 2 }, end: { line: 2, character: 2 } },
		}

		const result = buildInceptionNextEditPrompt(params)

		expect(result).toMatchSnapshot()
	})

	it("should match snapshot with all context types", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "class Calculator {\n  ",
			suffix: "\n}",
			selection: { start: { line: 1, character: 2 }, end: { line: 1, character: 2 } },
			pasteboardContent: "multiply(a: number, b: number): number",
			recentlyOpenedFiles: [{ filepath: "math.ts", content: "export const add = (a, b) => a + b" }],
			recentEdits: "+++ b/calculator.ts\n+class Calculator",
		}

		const result = buildInceptionNextEditPrompt(params)

		expect(result).toMatchSnapshot()
	})

	it("should calculate correct editable region range", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "line1\nline2\nline3\n",
			suffix: "\nline5\nline6",
			selection: { start: { line: 3, character: 0 }, end: { line: 3, character: 0 } },
		}

		const result = buildInceptionNextEditPrompt(params)

		// Editable region should start at cursor line (3) and extend 5 lines after
		expect(result.editableRegionRange.start.line).toBe(3) // beforeRegion has 3 lines ("line1", "line2", "line3")
		expect(result.editableRegionRange.start.character).toBe(0)
		// Should include current line + next 5 or until end
		expect(result.editableRegionRange.end.line).toBeGreaterThan(result.editableRegionRange.start.line)
	})

	it("should insert cursor token at correct position", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "hello ",
			suffix: "world",
			selection: { start: { line: 0, character: 6 }, end: { line: 0, character: 6 } },
		}

		const result = buildInceptionNextEditPrompt(params)

		// Cursor should be inserted between "hello " and "world"
		expect(result.prompt).toContain(`hello ${INCEPTION_CONSTANTS.CURSOR}world`)
	})

	it("should handle empty file", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "",
			suffix: "",
			selection: { start: { line: 0, character: 0 }, end: { line: 0, character: 0 } },
		}

		const result = buildInceptionNextEditPrompt(params)

		expect(result).toMatchSnapshot()
	})

	it("should limit recently opened files to 3", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "import ",
			suffix: "",
			selection: { start: { line: 0, character: 7 }, end: { line: 0, character: 7 } },
			recentlyOpenedFiles: [
				{ filepath: "file1.ts", content: "export const a = 1" },
				{ filepath: "file2.ts", content: "export const b = 2" },
				{ filepath: "file3.ts", content: "export const c = 3" },
				{ filepath: "file4.ts", content: "export const d = 4" }, // Should be excluded
				{ filepath: "file5.ts", content: "export const e = 5" }, // Should be excluded
			],
		}

		const result = buildInceptionNextEditPrompt(params)

		// Should only include first 3 files
		expect(result.prompt).toContain("file1.ts")
		expect(result.prompt).toContain("file2.ts")
		expect(result.prompt).toContain("file3.ts")
		expect(result.prompt).not.toContain("file4.ts")
		expect(result.prompt).not.toContain("file5.ts")
	})

	it("should include clipboard after recently opened files", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "const x = ",
			suffix: "",
			selection: { start: { line: 0, character: 10 }, end: { line: 0, character: 10 } },
			pasteboardContent: "clipboard content",
			recentlyOpenedFiles: [{ filepath: "file.ts", content: "file content" }],
		}

		const result = buildInceptionNextEditPrompt(params)

		// Clipboard should appear after recently opened files
		const fileIndex = result.prompt.indexOf("file content")
		const clipboardIndex = result.prompt.indexOf("clipboard content")
		expect(clipboardIndex).toBeGreaterThan(fileIndex)
		expect(result.prompt).toContain("code_snippet_file_path: clipboard")
	})

	it("should wrap snippets with correct markers", () => {
		const params: CodeCompletionRequestParams = {
			...baseParams,
			prefix: "test",
			suffix: "",
			selection: { start: { line: 0, character: 4 }, end: { line: 0, character: 4 } },
			recentlyOpenedFiles: [{ filepath: "test.ts", content: "content" }],
		}

		const result = buildInceptionNextEditPrompt(params)

		// Check that snippets are wrapped correctly
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.RECENTLY_VIEWED_CODE_SNIPPETS_OPEN)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.RECENTLY_VIEWED_CODE_SNIPPETS_CLOSE)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.RECENTLY_VIEWED_CODE_SNIPPET_OPEN)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.RECENTLY_VIEWED_CODE_SNIPPET_CLOSE)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.CURRENT_FILE_CONTENT_OPEN)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.CURRENT_FILE_CONTENT_CLOSE)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.CODE_TO_EDIT_OPEN)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.CODE_TO_EDIT_CLOSE)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.EDIT_DIFF_HISTORY_OPEN)
		expect(result.prompt).toContain(INCEPTION_CONSTANTS.EDIT_DIFF_HISTORY_CLOSE)
	})
})
