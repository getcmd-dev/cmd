import { describe, expect, it, beforeEach, jest } from "@jest/globals"
import { StreamingJsonParser } from "../streamingJSONParser"

describe("StreamingJsonParser", () => {
	let parser: StreamingJsonParser

	beforeEach(() => {
		parser = new StreamingJsonParser()
	})

	describe("processChunk", () => {
		it("should return empty array for incomplete JSON", () => {
			const result = parser.processChunk('{"name": "Jo')
			expect(result).toEqual([])
		})

		it("should parse single complete JSON object", () => {
			const result = parser.processChunk('{"name": "John", "age": 30}')
			expect(result).toEqual([{ name: "John", age: 30 }])
		})

		it("should parse multiple complete JSON objects in single chunk", () => {
			const result = parser.processChunk('{"id": 1}{"id": 2}{"id": 3}')
			expect(result).toEqual([{ id: 1 }, { id: 2 }, { id: 3 }])
		})

		it("should handle JSON object split across multiple chunks", () => {
			const result1 = parser.processChunk('{"name": "Jo')
			expect(result1).toEqual([])

			const result2 = parser.processChunk('hn", "age": 30}')
			expect(result2).toEqual([{ name: "John", age: 30 }])
		})

		it("should handle multiple objects with some split across chunks", () => {
			const result1 = parser.processChunk('{"id": 1}{"name": "A')
			expect(result1).toEqual([{ id: 1 }])

			const result2 = parser.processChunk('lice"}{"id": 2}')
			expect(result2).toEqual([{ name: "Alice" }, { id: 2 }])
		})

		it("should handle nested objects", () => {
			const result = parser.processChunk('{"user": {"name": "John", "details": {"age": 30}}}')
			expect(result).toEqual([{ user: { name: "John", details: { age: 30 } } }])
		})

		it("should handle arrays", () => {
			const result = parser.processChunk('{"items": [1, 2, 3], "count": 3}')
			expect(result).toEqual([{ items: [1, 2, 3], count: 3 }])
		})

		it("should handle nested arrays and objects", () => {
			const result = parser.processChunk('{"users": [{"name": "John"}, {"name": "Jane"}]}')
			expect(result).toEqual([{ users: [{ name: "John" }, { name: "Jane" }] }])
		})

		it("should ignore braces within strings", () => {
			const result = parser.processChunk('{"message": "Hello {world}", "count": 1}')
			expect(result).toEqual([{ message: "Hello {world}", count: 1 }])
		})

		it("should handle escaped quotes in strings", () => {
			const result = parser.processChunk('{"message": "She said \\"Hello\\"", "id": 1}')
			expect(result).toEqual([{ message: 'She said "Hello"', id: 1 }])
		})

		it("should handle escaped backslashes in strings", () => {
			const result = parser.processChunk('{"path": "C:\\\\Users\\\\John", "id": 1}')
			expect(result).toEqual([{ path: "C:\\Users\\John", id: 1 }])
		})

		it("should handle complex escaped sequences", () => {
			const result = parser.processChunk('{"text": "Line 1\\nLine 2\\tTabbed", "id": 1}')
			expect(result).toEqual([{ text: "Line 1\nLine 2\tTabbed", id: 1 }])
		})

		it("should handle strings containing braces and quotes", () => {
			const result = parser.processChunk('{"json": "{\\"key\\": \\"value\\"}", "valid": true}')
			expect(result).toEqual([{ json: '{"key": "value"}', valid: true }])
		})

		it("should handle empty objects", () => {
			const result = parser.processChunk("{}")
			expect(result).toEqual([{}])
		})

		it("should handle empty arrays", () => {
			const result = parser.processChunk('{"items": []}')
			expect(result).toEqual([{ items: [] }])
		})

		it("should handle whitespace between objects", () => {
			const result = parser.processChunk('{"id": 1}   {"id": 2}')
			expect(result).toEqual([{ id: 1 }, { id: 2 }])
		})

		it("should handle boolean and null values", () => {
			const result = parser.processChunk('{"active": true, "data": null, "disabled": false}')
			expect(result).toEqual([{ active: true, data: null, disabled: false }])
		})

		it("should handle numbers including decimals and scientific notation", () => {
			const result = parser.processChunk('{"int": 42, "float": 3.14, "scientific": 1.23e-4}')
			expect(result).toEqual([{ int: 42, float: 3.14, scientific: 1.23e-4 }])
		})

		it("should continue processing after invalid JSON", () => {
			// Mock console.warn to avoid noise in test output
			const originalWarn = console.warn
			console.warn = jest.fn()

			const result = parser.processChunk('{"invalid": unclosed}{"valid": true}')
			expect(result).toEqual([{ valid: true }])

			console.warn = originalWarn
		})

		it("should handle very long strings", () => {
			const longString = "x".repeat(10000)
			const result = parser.processChunk(`{"data": "${longString}"}`)
			expect(result).toEqual([{ data: longString }])
		})

		it("should handle deeply nested structures", () => {
			const deepObj = '{"a": {"b": {"c": {"d": {"e": "deep"}}}}}'
			const result = parser.processChunk(deepObj)
			expect(result).toEqual([{ a: { b: { c: { d: { e: "deep" } } } } }])
		})

		it("should handle mixed data types in arrays", () => {
			const result = parser.processChunk('{"mixed": [1, "string", true, null, {"nested": "object"}]}')
			expect(result).toEqual([{ mixed: [1, "string", true, null, { nested: "object" }] }])
		})

		it("should handle string with only escaped characters", () => {
			const result = parser.processChunk('{"escaped": "\\\\\\"\\t\\n\\r"}')
			expect(result).toEqual([{ escaped: '\\"\t\n\r' }])
		})

		it("should process chunk by chunk correctly with partial objects", () => {
			// Simulate streaming a large object in small chunks
			let result = parser.processChunk('{"users":')
			expect(result).toEqual([])

			result = parser.processChunk('[{"name":')
			expect(result).toEqual([])

			result = parser.processChunk('"John","age"')
			expect(result).toEqual([])

			result = parser.processChunk(':30},{"name":"Jane"')
			expect(result).toEqual([])

			result = parser.processChunk(',"age":25}]}')
			expect(result).toEqual([
				{
					users: [
						{ name: "John", age: 30 },
						{ name: "Jane", age: 25 },
					],
				},
			])
		})

		it("should handle Unicode characters", () => {
			const result = parser.processChunk('{"emoji": "🚀", "chinese": "你好", "arabic": "مرحبا"}')
			expect(result).toEqual([{ emoji: "🚀", chinese: "你好", arabic: "مرحبا" }])
		})

		it("should reset state correctly after parsing object", () => {
			// Parse first object
			const result1 = parser.processChunk('{"first": true}')
			expect(result1).toEqual([{ first: true }])

			// Parse second object in separate chunk
			const result2 = parser.processChunk('{"second": true}')
			expect(result2).toEqual([{ second: true }])
		})
	})

	describe("edge cases and error handling", () => {
		it("should handle empty chunks", () => {
			const result = parser.processChunk("")
			expect(result).toEqual([])
		})

		it("should handle chunks with only whitespace", () => {
			const result = parser.processChunk("   \n\t  ")
			expect(result).toEqual([])
		})

		it("should handle malformed JSON gracefully", () => {
			const originalWarn = console.warn
			console.warn = jest.fn()

			const result = parser.processChunk('{"malformed": }')
			expect(result).toEqual([])
			expect(console.warn).toHaveBeenCalled()

			console.warn = originalWarn
		})

		it("should continue processing after encountering malformed JSON", () => {
			const originalWarn = console.warn
			console.warn = jest.fn()

			const result = parser.processChunk('{"bad": }{"good": "value"}')
			expect(result).toEqual([{ good: "value" }])

			console.warn = originalWarn
		})

		it("should handle unmatched opening braces", () => {
			const result1 = parser.processChunk('{"unclosed": {"nested": true')
			expect(result1).toEqual([])

			// Even after adding more data, it should not parse until properly closed
			const result2 = parser.processChunk(', "more": "data"')
			expect(result2).toEqual([])

			// Only when properly closed should it parse
			const result3 = parser.processChunk("}}")
			expect(result3).toEqual([{ unclosed: { nested: true, more: "data" } }])
		})
	})
})
