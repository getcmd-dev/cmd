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
		const result = formatSnippetAsComments("def test():\n  pass", "test.py", "public.python-script")
		expect(result).toContain("# Path: test.py")
		expect(result).toContain("# def test():")
		expect(result).toContain("#   pass")
	})

	it("should format Swift with // comments", () => {
		const result = formatSnippetAsComments("func test() {}", "test.swift", "public.swift-source")
		expect(result).toContain("// Path: test.swift")
		expect(result).toContain("// func test() {}")
	})

	it("should format TypeScript with // comments", () => {
		const result = formatSnippetAsComments("function test() {}", "test.ts", "public.typescript-source")
		expect(result).toContain("// Path: test.ts")
		expect(result).toContain("// function test() {}")
	})

	it("should use // as default for unknown UTI", () => {
		const result = formatSnippetAsComments("content", "test.xyz", "unknown.file")
		expect(result).toContain("// Path: test.xyz")
		expect(result).toContain("// content")
	})

	it("should handle multi-line content", () => {
		const content = "line1\nline2\nline3"
		const result = formatSnippetAsComments(content, "test.swift", "public.swift-source")
		expect(result).toContain("// line1")
		expect(result).toContain("// line2")
		expect(result).toContain("// line3")
	})

	it("should preserve indentation", () => {
		const content = "func test() {\n  let x = 1\n}"
		const result = formatSnippetAsComments(content, "test.swift", "public.swift-source")
		expect(result).toContain("//   let x = 1")
	})

	it("should handle empty content", () => {
		const result = formatSnippetAsComments("", "test.swift", "public.swift-source")
		expect(result).toContain("// Path: test.swift")
	})
})

describe("rankSnippets", () => {
	it("should respect token budget limits", () => {
		const snippets: CodeSnippet[] = [
			{ filepath: "file1.swift", content: "a".repeat(1000), type: "clipboard" },
			{ filepath: "file2.swift", content: "b".repeat(1000), type: "recentEdit" },
			{ filepath: "file3.swift", content: "c".repeat(1000), type: "recentFile" },
		]

		const budget = { ...DEFAULT_TOKEN_BUDGET, maxPromptTokens: 100 }
		const ranked = rankSnippets(snippets, "public.swift-source", budget)

		// Total tokens should not exceed budget
		const totalTokens = ranked.reduce((sum, s) => sum + countTokens(s.content), 0)
		expect(totalTokens).toBeLessThanOrEqual(budget.maxPromptTokens)
	})

	it("should prioritize clipboard over recent edits", () => {
		const snippets: CodeSnippet[] = [
			{ filepath: "file1.swift", content: "recent edit", type: "recentEdit" },
			{ filepath: "file2.swift", content: "clipboard content", type: "clipboard" },
		]

		const ranked = rankSnippets(snippets, "public.swift-source", DEFAULT_TOKEN_BUDGET)

		// Clipboard should come first
		expect(ranked[0].type).toBe("clipboard")
	})

	it("should deduplicate exact matches", () => {
		const snippets: CodeSnippet[] = [
			{ filepath: "file1.swift", content: "duplicate", type: "clipboard" },
			{ filepath: "file2.swift", content: "duplicate", type: "recentEdit" },
		]

		const ranked = rankSnippets(snippets, "public.swift-source", DEFAULT_TOKEN_BUDGET)

		// Should only include one copy
		expect(ranked.length).toBe(1)
	})

	it("should truncate snippets to fit budget", () => {
		const snippets: CodeSnippet[] = [{ filepath: "file.swift", content: "x".repeat(10000), type: "clipboard" }]

		const budget = { ...DEFAULT_TOKEN_BUDGET, maxPromptTokens: 100 }
		const ranked = rankSnippets(snippets, "public.swift-source", budget)

		expect(ranked.length).toBeGreaterThan(0)
		const tokens = countTokens(ranked[0].content)
		expect(tokens).toBeLessThanOrEqual(budget.maxPromptTokens)
	})

	it("should handle empty snippets array", () => {
		const ranked = rankSnippets([], "public.swift-source", DEFAULT_TOKEN_BUDGET)
		expect(ranked).toEqual([])
	})

	it("should handle snippets with empty content", () => {
		const snippets: CodeSnippet[] = [{ filepath: "empty.swift", content: "", type: "clipboard" }]

		const ranked = rankSnippets(snippets, "public.swift-source", DEFAULT_TOKEN_BUDGET)
		expect(ranked.length).toBe(0) // Empty snippets should be filtered out
	})

	it("should prioritize by type: clipboard > recentEdit > recentFile > currentFile", () => {
		const snippets: CodeSnippet[] = [
			{ filepath: "current.swift", content: "current file", type: "currentFile" },
			{ filepath: "recent.swift", content: "recent file", type: "recentFile" },
			{ filepath: "edit.swift", content: "recent edit", type: "recentEdit" },
			{ filepath: "clip.swift", content: "clipboard", type: "clipboard" },
		]

		const ranked = rankSnippets(snippets, "public.swift-source", DEFAULT_TOKEN_BUDGET)

		expect(ranked[0].type).toBe("clipboard")
		expect(ranked[1].type).toBe("recentEdit")
		expect(ranked[2].type).toBe("recentFile")
		expect(ranked[3].type).toBe("currentFile")
	})
})

describe("buildInstructPrompt", () => {
	it("should match snapshot for basic prefix/suffix", () => {
		const prompt = buildInstructPrompt({
			prefix: "function test() {",
			suffix: "}",
			filepath: "test.ts",
			selection: { start: { line: 0, character: 16 }, end: { line: 0, character: 16 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toMatchSnapshot()
	})

	it("should include prefix and suffix", () => {
		const prompt = buildInstructPrompt({
			prefix: "function test() {",
			suffix: "}",
			filepath: "test.ts",
			selection: { start: { line: 0, character: 16 }, end: { line: 0, character: 16 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toContain("function test() {")
		expect(prompt).toContain("}")
		expect(prompt).toContain("<COMPLETION_TARGET />")
	})

	it("should match snapshot with clipboard content", () => {
		const prompt = buildInstructPrompt({
			prefix: "let x = ",
			suffix: "",
			filepath: "test.ts",
			pasteboardContent: "42",
			selection: { start: { line: 0, character: 8 }, end: { line: 0, character: 8 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toMatchSnapshot()
	})

	it("should include clipboard content when provided", () => {
		const prompt = buildInstructPrompt({
			prefix: "let x = ",
			suffix: "",
			filepath: "test.ts",
			pasteboardContent: "42",
			selection: { start: { line: 0, character: 8 }, end: { line: 0, character: 8 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toContain("clipboard")
		expect(prompt).toContain("42")
	})

	it("should match snapshot with recent edits", () => {
		const prompt = buildInstructPrompt({
			prefix: "let x = ",
			suffix: "",
			filepath: "test.ts",
			recentEdits: "diff --git a/file.ts b/file.ts\n+let y = 1",
			selection: { start: { line: 0, character: 8 }, end: { line: 0, character: 8 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toMatchSnapshot()
	})

	it("should include recent edits when provided", () => {
		const prompt = buildInstructPrompt({
			prefix: "let x = ",
			suffix: "",
			filepath: "test.ts",
			recentEdits: "previous changes",
			selection: { start: { line: 0, character: 8 }, end: { line: 0, character: 8 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toContain("recent edits")
		expect(prompt).toContain("previous changes")
	})

	it("should match snapshot with recently opened files", () => {
		const prompt = buildInstructPrompt({
			prefix: "import ",
			suffix: "",
			filepath: "test.ts",
			recentlyOpenedFiles: [
				{ filepath: "/workspace/src/helper.ts", content: "export function help() {}" },
				{ filepath: "/workspace/src/utils.ts", content: "export const PI = 3.14" },
			],
			selection: { start: { line: 0, character: 7 }, end: { line: 0, character: 7 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toMatchSnapshot()
	})

	it("should include recently opened files when provided", () => {
		const prompt = buildInstructPrompt({
			prefix: "import ",
			suffix: "",
			filepath: "test.ts",
			recentlyOpenedFiles: [
				{ filepath: "helper.ts", content: "export function help() {}" },
				{ filepath: "utils.ts", content: "export const PI = 3.14" },
			],
			selection: { start: { line: 0, character: 7 }, end: { line: 0, character: 7 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toContain("helper.ts")
		expect(prompt).toContain("utils.ts")
	})

	it("should handle empty prefix", () => {
		const prompt = buildInstructPrompt({
			prefix: "",
			suffix: "function test() {}",
			filepath: "test.ts",
			selection: { start: { line: 0, character: 0 }, end: { line: 0, character: 0 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toContain("<COMPLETION_TARGET />")
		expect(prompt).toContain("function test() {}")
	})

	it("should handle empty suffix", () => {
		const prompt = buildInstructPrompt({
			prefix: "function test() {}",
			suffix: "",
			filepath: "test.ts",
			selection: { start: { line: 0, character: 18 }, end: { line: 0, character: 18 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		expect(prompt).toContain("function test() {}")
		expect(prompt).toContain("<COMPLETION_TARGET />")
	})

	it("should respect token budget and omit low-priority snippets", () => {
		const prompt = buildInstructPrompt({
			prefix: "x",
			suffix: "y",
			filepath: "test.ts",
			pasteboardContent: "a".repeat(5000),
			recentEdits: "b".repeat(5000),
			recentlyOpenedFiles: [{ filepath: "big.ts", content: "c".repeat(5000) }],
			selection: { start: { line: 0, character: 1 }, end: { line: 0, character: 1 } },
			formattingMetadata: {
				tabSize: 2,
				indentSize: 2,
				usesTabsForIndentation: false,
				uti: "public.typescript-source",
			},
		})

		// Should include high-priority clipboard but may omit low-priority items
		expect(prompt.length).toBeLessThan(20000) // Reasonable limit
	})
})
