import { JSONL } from "@/utils/jsonl"

describe("JSONL.parse", () => {
	test("parses multiple single-line JSON objects (with trailing newline)", () => {
		const content = '{"name":"John"}\n{"age":30}\n{"city":"NYC"}\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ name: "John" }, { age: 30 }, { city: "NYC" }])
	})

	test("parses multiple single-line JSON objects (no trailing newline)", () => {
		const content = '{"name":"John"}\n{"age":30}\n{"city":"NYC"}'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ name: "John" }, { age: 30 }, { city: "NYC" }])
	})

	test("parses arrays as JSONL entries", () => {
		const content = '["a",1]\n[{"x":1},{"y":2}]\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([
			["a", 1],
			[{ x: 1 }, { y: 2 }],
		])
	})

	test("handles nested and multi-line JSON objects", () => {
		const content = '{\n  "a": {\n    "b": [1, 2, { "c": "d" }]\n  }\n}\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ a: { b: [1, 2, { c: "d" }] } }])
	})

	test("does not miscount braces/brackets inside strings and escaped quotes", () => {
		const content = '{"text":"He said: \\"{[ok]}\\" and left"}\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ text: 'He said: "{[ok]}" and left' }])
	})

	test("ignores blank lines between entries", () => {
		const content = '{"a":1}\n\n  \n{"b":2}\n\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ a: 1 }, { b: 2 }])
	})

	test("handles CRLF (Windows) line endings", () => {
		const content = '{"a":1}\r\n{"b":2}\r\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ a: 1 }, { b: 2 }])
	})

	test("throws on invalid JSON lines", () => {
		const content = '{"a":1}\n{invalid}\n{"b":2}\n'
		expect(() => JSONL.parse(content)).toThrow(/Parse error/)
	})

	test("returns empty array for empty content", () => {
		const result = JSONL.parse("")
		expect(result).toEqual([])
	})

	test("throws on incomplete last JSON (no newline)", () => {
		const content = '{"a":1}\n{"b":'
		expect(() => JSONL.parse(content)).toThrow(/Parse error for last object/)
	})

	test("throws on invalid last line without newline", () => {
		const content = '{"a":1}\n{invalid}'
		expect(() => JSONL.parse(content)).toThrow(/Parse error for last object/)
	})

	test("handles trailing spaces and tabs around entries", () => {
		const content = '  {"a":1} \t\n\t {"b":2}  \n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ a: 1 }, { b: 2 }])
	})

	test("handles mixed LF and CRLF line endings", () => {
		const content = '{"a":1}\r\n{"b":2}\n{"c":3}\r\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ a: 1 }, { b: 2 }, { c: 3 }])
	})

	test("parses multi-line arrays as entries", () => {
		const content = '[\n  1,\n  2,\n  {"a":3}\n]\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([[1, 2, { a: 3 }]])
	})

	test("handles escaped backslashes in strings", () => {
		const content = '{"path":"C:\\\\Users\\\\John"}\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ path: "C:\\Users\\John" }])
	})

	test("handles newline escapes within string values", () => {
		const content = '{"text":"Line 1\\nLine 2"}\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ text: "Line 1\nLine 2" }])
	})

	test("handles CRLF escapes within string values", () => {
		const content = '{"text":"Line 1\\r\\nLine 2"}\n'
		const result = JSONL.parse(content)
		expect(result).toEqual([{ text: "Line 1\r\nLine 2" }])
	})
})
