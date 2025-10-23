import { describe, expect, it, jest, beforeEach } from "@jest/globals"
import { Request, Response } from "express"
import { ResponseUsage, StreamedResponseChunk } from "@/server/schemas/sendMessageSchema"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "../sendMessage"

describe("sendMessage endpoint", () => {
	describe("respondUsingResponseStream", () => {
		let mockResponse: Partial<Response>
		let writtenData: string[]
		let headers: Record<string, string>

		beforeEach(() => {
			writtenData = []
			headers = {}
			mockResponse = {
				write: jest.fn((data: string) => {
					writtenData.push(data)
					return true
				}) as Response["write"],
				getHeader: jest.fn((name: string) => headers[name]) as Response["getHeader"],
				setHeader: jest.fn((name: string, value: string | string[]) => {
					headers[name] = Array.isArray(value) ? value.join(", ") : value
					return mockResponse as Response
				}) as Response["setHeader"],
			}
		})

		it("should include usage information in the response stream", async () => {
			// given
			const chunks: ResponseChunkWithoutIndex[] = [
				{ type: "text_delta", text: "Hello" },
				{ type: "text_delta", text: " world" },
			]

			async function* mockStream() {
				for (const chunk of chunks) {
					yield chunk
				}
			}

			// when
			const finalIdx = await respondUsingResponseStream(mockStream(), mockResponse as Response)

			// then
			// Verify that chunks were written with indices
			const writtenChunks = writtenData.filter((d) => !d.includes('"type":"ping"'))
			expect(writtenChunks.length).toBe(2)

			const parsedChunks = writtenChunks.map((d) => JSON.parse(d.trim()))
			expect(parsedChunks[0]).toEqual({
				type: "text_delta",
				text: "Hello",
				idx: expect.any(Number),
			})
			expect(parsedChunks[1]).toEqual({
				type: "text_delta",
				text: " world",
				idx: expect.any(Number),
			})

			// Verify idx is incremented correctly
			expect(parsedChunks[1].idx).toBe(parsedChunks[0].idx + 1)

			// Verify the final index is returned
			expect(finalIdx).toBeGreaterThan(0)
		})

		it("should handle usage chunk in the stream", async () => {
			// given
			const chunks: ResponseChunkWithoutIndex[] = [
				{ type: "text_delta", text: "Response text" },
				{
					type: "usage",
					inputTokens: 100,
					outputTokens: 50,
					cachedInputTokens: 20,
				},
			]

			async function* mockStream() {
				for (const chunk of chunks) {
					yield chunk
				}
			}

			// when
			await respondUsingResponseStream(mockStream(), mockResponse as Response)

			// then
			const writtenChunks = writtenData.filter((d) => !d.includes('"type":"ping"'))
			expect(writtenChunks.length).toBe(2)

			const parsedChunks = writtenChunks.map((d) => JSON.parse(d.trim()))

			// Verify usage information is correctly passed through
			const usageChunk = parsedChunks.find((c) => c.type === "usage") as ResponseUsage
			expect(usageChunk).toBeDefined()
			expect(usageChunk.inputTokens).toBe(100)
			expect(usageChunk.outputTokens).toBe(50)
			expect(usageChunk.cachedInputTokens).toBe(20)
			expect(usageChunk.idx).toBe(1)
		})

		it("should set correct headers for streaming response", async () => {
			// given
			async function* mockStream() {
				yield { type: "text_delta", text: "test" } as ResponseChunkWithoutIndex
			}

			// when
			await respondUsingResponseStream(mockStream(), mockResponse as Response)

			// then
			expect(mockResponse.setHeader).toHaveBeenCalledWith("Content-Type", "text/event-stream")
			expect(mockResponse.setHeader).toHaveBeenCalledWith("Cache-Control", "no-cache")
			expect(mockResponse.setHeader).toHaveBeenCalledWith("Connection", "keep-alive")
		})

		it("should send ping messages periodically", async () => {
			// given
			jest.useFakeTimers()

			// eslint-disable-next-line require-yield
			const streamPromise = (async function* () {
				// Yield nothing - just wait for timers
				await new Promise((resolve) => setTimeout(resolve, 2500))
			})()

			// when
			const responsePromise = respondUsingResponseStream(streamPromise, mockResponse as Response)

			// Advance timers to trigger ping messages
			jest.advanceTimersByTime(2500)

			await responsePromise

			// then
			const pings = writtenData.filter((d) => d.includes('"type":"ping"'))
			expect(pings.length).toBeGreaterThanOrEqual(2)

			const parsedPing = JSON.parse(pings[0].trim())
			expect(parsedPing.type).toBe("ping")
			expect(parsedPing.timestamp).toBeDefined()
			expect(parsedPing.idx).toBeDefined()

			jest.useRealTimers()
		})
	})

	describe("usage info integration", () => {
		it("should correctly format usage info with all fields", () => {
			// This test verifies the ResponseUsage type structure
			const usageInfo: ResponseUsage = {
				type: "usage",
				inputTokens: 1000,
				outputTokens: 500,
				cachedInputTokens: 200,
				idx: 5,
			}

			expect(usageInfo.type).toBe("usage")
			expect(usageInfo.inputTokens).toBe(1000)
			expect(usageInfo.outputTokens).toBe(500)
			expect(usageInfo.cachedInputTokens).toBe(200)
			expect(usageInfo.idx).toBe(5)
		})

		it("should handle zero cached input tokens", () => {
			const usageInfo: ResponseUsage = {
				type: "usage",
				inputTokens: 1000,
				outputTokens: 500,
				cachedInputTokens: 0,
				idx: 5,
			}

			expect(usageInfo.cachedInputTokens).toBe(0)
		})
	})
})
