import { describe, expect, it } from "@jest/globals"
import { ToolCallContent } from "@agentclientprotocol/sdk"
import { mapToolCallContent } from "../helper"
import { ACPTool_Content } from "@/server/schemas/toolsSchema"

describe("mapToolCallContent", () => {
	describe("diff type", () => {
		it("should map diff tool call correctly", () => {
			const diffToolCall: ToolCallContent = {
				type: "diff",
				path: "/path/to/file.txt",
				newText: "new content",
				oldText: "old content",
			}

			const result = mapToolCallContent(diffToolCall)

			expect(result).toEqual({
				type: "diff",
				path: "/path/to/file.txt",
				newText: "new content",
				oldText: "old content",
			})
		})
	})

	describe("terminal type", () => {
		it("should map terminal tool call correctly", () => {
			const terminalToolCall: ToolCallContent = {
				type: "terminal",
				terminalId: "terminal-123",
			}

			const result = mapToolCallContent(terminalToolCall)

			expect(result).toEqual({
				type: "terminal",
				terminalId: "terminal-123",
			})
		})
	})

	describe("content type with text", () => {
		it("should map text content correctly", () => {
			const textToolCall: ToolCallContent = {
				type: "content",
				content: {
					type: "text",
					text: "Hello, world!",
				},
			}

			const result = mapToolCallContent(textToolCall)

			expect(result).toEqual({
				type: "content",
				content: {
					type: "text",
					text: "Hello, world!",
				},
			})
		})
	})

	describe("content type with image", () => {
		it("should map image content correctly", () => {
			const imageToolCall: ToolCallContent = {
				type: "content",
				content: {
					type: "image",
					data: "base64imagedata",
					mimeType: "image/png",
				},
			}

			const result = mapToolCallContent(imageToolCall)

			expect(result).toEqual({
				type: "content",
				content: {
					type: "image",
					data: "base64imagedata",
					mimeType: "image/png",
				},
			})
		})
	})

	describe("content type with audio", () => {
		it("should map audio content correctly", () => {
			const audioToolCall: ToolCallContent = {
				type: "content",
				content: {
					type: "audio",
					data: "base64audiodata",
					mimeType: "audio/mp3",
				},
			}

			const result = mapToolCallContent(audioToolCall)

			expect(result).toEqual({
				type: "content",
				content: {
					type: "audio",
					data: "base64audiodata",
					mimeType: "audio/mp3",
				},
			})
		})
	})

	describe("content type with embedded resource", () => {
		it("should map embedded text resource correctly", () => {
			const resourceToolCall: ToolCallContent = {
				type: "content",
				content: {
					type: "resource",
					resource: {
						uri: "file:///path/to/file.txt",
						mimeType: "text/plain",
						text: "file content",
					},
				},
			}

			const result = mapToolCallContent(resourceToolCall)

			expect(result).toEqual({
				type: "content",
				content: {
					type: "resource",
					resource: {
						type: "embedded_resource_text",
						uri: "file:///path/to/file.txt",
						mimeType: "text/plain",
						text: "file content",
					},
				},
			})
		})

		it("should map embedded blob resource correctly", () => {
			const resourceToolCall: ToolCallContent = {
				type: "content",
				content: {
					type: "resource",
					resource: {
						uri: "file:///path/to/file.bin",
						mimeType: "application/octet-stream",
						blob: "base64blobdata",
					},
				},
			}

			const result = mapToolCallContent(resourceToolCall)

			expect(result).toEqual({
				type: "content",
				content: {
					type: "resource",
					resource: {
						type: "embedded_resource_blob",
						uri: "file:///path/to/file.bin",
						mimeType: "application/octet-stream",
						blob: "base64blobdata",
					},
				},
			})
		})
	})

	describe("error handling", () => {
		it("should throw error for unsupported content type", () => {
			const unsupportedToolCall = {
				type: "content",
				content: {
					type: "unsupported" as any,
				},
			} as ToolCallContent

			expect(() => mapToolCallContent(unsupportedToolCall)).toThrow("Unsupported content type: unsupported")
		})
	})

	describe("type safety", () => {
		it("should return ACPTool_Content type", () => {
			const diffToolCall: ToolCallContent = {
				type: "diff",
				path: "/test.txt",
				newText: "test",
			}

			const result: ACPTool_Content = mapToolCallContent(diffToolCall)

			// This test primarily verifies TypeScript compilation
			// If it compiles, the type is correct
			expect(result.type).toBe("diff")
		})
	})
})
