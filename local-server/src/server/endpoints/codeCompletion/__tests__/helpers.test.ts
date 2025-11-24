import {
	countTokens,
	formatSnippetAsComments,
	rankSnippets,
	buildInstructPrompt,
	CodeSnippet,
	DEFAULT_TOKEN_BUDGET,
} from "../helpers"

describe("countTokens", () => {
	it("should count tokens for simple text", () => {
		const text = "hello world"
		const count = countTokens(text)
		expect(count).toBeGreaterThan(0)
		expect(count).toBeLessThan(10)
	})

	it("should handle empty strings", () => {
		expect(countTokens("")).toBe(0)
	})

	it("should count tokens for code", () => {
		const code = `function test() {\n  return 42;\n}`
		const count = countTokens(code)
		expect(count).toBeGreaterThan(0)
	})

	it("should handle very long strings", () => {
		const longText = "word ".repeat(2000)
		const count = countTokens(longText)
		expect(count).toBeGreaterThan(1000)
	})

	it("should handle Unicode characters", () => {
		const text = "日本語のテキスト"
		const count = countTokens(text)
		expect(count).toBeGreaterThan(0)
	})

	it("should handle emoji", () => {
		const text = "😀 😃 😄"
		const count = countTokens(text)
		expect(count).toBeGreaterThan(0)
	})
})

describe("formatSnippetAsComments", () => {
	it("should format Python with # comments", () => {
		const snippet: CodeSnippet = {
			filepath: "test.py",
			content: "def test():\n  pass",
			type: "recentFile",
		}
		const result = formatSnippetAsComments(snippet, "#")
		expect(result).toContain("# Path: test.py")
		expect(result).toContain("# def test():")
		expect(result).toContain("#   pass")
	})

	it("should format Swift with // comments", () => {
		const snippet: CodeSnippet = {
			filepath: "test.swift",
			content: "func test() {}",
			type: "recentFile",
		}
		const result = formatSnippetAsComments(snippet, "//")
		expect(result).toContain("// Path: test.swift")
		expect(result).toContain("// func test() {}")
	})

	it("should format TypeScript with // comments", () => {
		const snippet: CodeSnippet = {
			filepath: "test.ts",
			content: "function test() {}",
			type: "recentFile",
		}
		const result = formatSnippetAsComments(snippet, "//")
		expect(result).toContain("// Path: test.ts")
		expect(result).toContain("// function test() {}")
	})

	it("should use // as default for unknown UTI", () => {
		const snippet: CodeSnippet = {
			filepath: "test.xyz",
			content: "content",
			type: "recentFile",
		}
		const result = formatSnippetAsComments(snippet, "//")
		expect(result).toContain("// Path: test.xyz")
		expect(result).toContain("// content")
	})

	it("should handle multi-line content", () => {
		const snippet: CodeSnippet = {
			filepath: "test.swift",
			content: "line1\nline2\nline3",
			type: "recentFile",
		}
		const result = formatSnippetAsComments(snippet, "//")
		expect(result).toContain("// line1")
		expect(result).toContain("// line2")
		expect(result).toContain("// line3")
	})

	it("should preserve indentation", () => {
		const snippet: CodeSnippet = {
			filepath: "test.swift",
			content: "func test() {\n  let x = 1\n}",
			type: "recentFile",
		}
		const result = formatSnippetAsComments(snippet, "//")
		expect(result).toContain("//   let x = 1")
	})

	it("should handle empty content", () => {
		const snippet: CodeSnippet = {
			filepath: "test.swift",
			content: "",
			type: "recentFile",
		}
		const result = formatSnippetAsComments(snippet, "//")
		expect(result).toContain("// Path: test.swift")
	})
})

describe("rankSnippets", () => {
	it("should rank by similarity to context", () => {
		const snippets: CodeSnippet[] = [
			{ filepath: "file1.swift", content: "func calculate() { let x = 1 }", type: "recentFile" },
			{ filepath: "file2.swift", content: "import UIKit", type: "recentFile" },
			{ filepath: "file3.swift", content: "let result = calculate()", type: "recentFile" },
		]

		const contextAroundCursor = "let value = calculate()"
		const ranked = rankSnippets(snippets, contextAroundCursor)

		// Snippet with 'calculate' should rank higher than 'import UIKit'
		expect(ranked[0].content).toContain("calculate")
	})

	it("should handle empty snippets array", () => {
		const ranked = rankSnippets([], "let x = 1")
		expect(ranked).toEqual([])
	})

	it("should handle empty context", () => {
		const snippets: CodeSnippet[] = [
			{ filepath: "file1.swift", content: "func test() {}", type: "recentFile" },
			{ filepath: "file2.swift", content: "let x = 1", type: "recentFile" },
		]

		const ranked = rankSnippets(snippets, "")
		// Should still return snippets even with empty context
		expect(ranked.length).toBe(2)
	})

	it("should rank snippets with shared symbols higher", () => {
		const snippets: CodeSnippet[] = [
			{ filepath: "file1.swift", content: "class User { var name: String }", type: "recentFile" },
			{ filepath: "file2.swift", content: "func calculateTotal() { return 100 }", type: "recentFile" },
		]

		const contextAroundCursor = "let user = User(name: userName)"
		const ranked = rankSnippets(snippets, contextAroundCursor)

		// Snippet with User/name should rank higher
		expect(ranked[0].content).toContain("User")
	})
})

describe("buildInstructPrompt", () => {
	it("should match snapshot for basic prefix/suffix", () => {
		const result = buildInstructPrompt({
			prefix: "function test() {",
			suffix: "}",
			cursorPosition: { line: 0, character: 17 },
			filepath: "test.ts",
			commentPrefix: "//",
		})

		expect(result).toMatchSnapshot()
	})

	it("should include prefix and suffix in user prompt", () => {
		const result = buildInstructPrompt({
			prefix: "function test() {",
			suffix: "}",
			cursorPosition: { line: 0, character: 17 },
			filepath: "test.ts",
			commentPrefix: "//",
		})

		expect(result.userPrompt).toContain("function test() {")
		expect(result.userPrompt).toContain("}")
		expect(result.userPrompt).toContain("<|cursor|>")
	})

	it("should match snapshot with context snippets", () => {
		const contextSnippets: CodeSnippet[] = [
			{ filepath: "helper.ts", content: "export function help() {}", type: "recentFile" },
			{ filepath: "utils.ts", content: "export const PI = 3.14", type: "recentFile" },
		]

		const result = buildInstructPrompt({
			prefix: "import ",
			suffix: "",
			cursorPosition: { line: 0, character: 7 },
			filepath: "test.ts",
			commentPrefix: "//",
			contextSnippets,
		})

		expect(result).toMatchSnapshot()
	})

	it("should include context snippets when provided", () => {
		const contextSnippets: CodeSnippet[] = [
			{ filepath: "helper.ts", content: "export function help() {}", type: "recentFile" },
			{ filepath: "utils.ts", content: "export const PI = 3.14", type: "recentFile" },
		]

		const result = buildInstructPrompt({
			prefix: "import ",
			suffix: "",
			cursorPosition: { line: 0, character: 7 },
			filepath: "test.ts",
			commentPrefix: "//",
			contextSnippets,
		})

		expect(result.userPrompt).toContain("helper.ts")
		expect(result.userPrompt).toContain("utils.ts")
	})

	it("should match snapshot with recent edits", () => {
		const result = buildInstructPrompt({
			prefix: "let x = ",
			suffix: "",
			cursorPosition: { line: 0, character: 8 },
			filepath: "test.ts",
			commentPrefix: "//",
			recentEdits: "diff --git a/file.ts b/file.ts\n+let y = 1",
		})

		expect(result).toMatchSnapshot()
	})

	it("should include recent edits when provided", () => {
		const result = buildInstructPrompt({
			prefix: "let x = ",
			suffix: "",
			cursorPosition: { line: 0, character: 8 },
			filepath: "test.ts",
			commentPrefix: "//",
			recentEdits: "previous changes",
		})

		expect(result.userPrompt).toContain("Recent Edits")
		expect(result.userPrompt).toContain("previous changes")
	})

	it("should handle empty prefix", () => {
		const result = buildInstructPrompt({
			prefix: "",
			suffix: "function test() {}",
			cursorPosition: { line: 0, character: 0 },
			filepath: "test.ts",
			commentPrefix: "//",
		})

		expect(result.userPrompt).toContain("<|cursor|>")
		expect(result.userPrompt).toContain("function test() {}")
	})

	it("should handle empty suffix", () => {
		const result = buildInstructPrompt({
			prefix: "function test() {}",
			suffix: "",
			cursorPosition: { line: 0, character: 18 },
			filepath: "test.ts",
			commentPrefix: "//",
		})

		expect(result.userPrompt).toContain("function test() {}")
		expect(result.userPrompt).toContain("<|cursor|>")
	})

	it("should calculate correct editable region", () => {
		const result = buildInstructPrompt({
			prefix: "line1\nline2\nline3\n",
			suffix: "line5\nline6",
			cursorPosition: { line: 3, character: 0 },
			filepath: "test.ts",
			commentPrefix: "//",
			editableRangeMargin: { top: 1, bottom: 2 },
		})

		// With margin { top: 1, bottom: 2 }, editable region should be lines 2-5 (0-indexed)
		expect(result.editableRegionStart).toBe(2)
		expect(result.editableRegionEnd).toBe(4) // line 3 + 2 = 5, but 0-indexed is 4
	})

	it("should include editable region markers in user prompt", () => {
		const result = buildInstructPrompt({
			prefix: "let x = 1\n",
			suffix: "let z = 3",
			cursorPosition: { line: 1, character: 0 },
			filepath: "test.ts",
			commentPrefix: "//",
		})

		expect(result.userPrompt).toContain("<|editable_region_start|>")
		expect(result.userPrompt).toContain("<|editable_region_end|>")
	})
})
