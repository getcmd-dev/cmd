import { describe, expect, it, jest, beforeEach, beforeAll } from "@jest/globals"
import { Response } from "express"
import { LocalExecutable, Message, StreamedResponseChunk } from "../../../../schemas/sendMessageSchema"
import { MockedSpawn, mockSpawn } from "@/utils/tests/mockSpawn"
import { MockedFs, mockFs } from "@/utils/tests/mockFs"
import { MockResponse } from "@/utils/tests/mockResponse"
import { SDKMessage } from "@anthropic-ai/claude-code"

describe("sendMessageToClaudeCode", () => {
	let sendMessageToClaudeCode: typeof import("../sendMessageToClaudeCode").sendMessageToClaudeCode
	let res: MockResponse
	let spawned: MockedSpawn
	let spawnCommand: string
	let spawnArgs: string[]
	let mockedFs: MockedFs

	beforeAll(async () => {
		// Mock child_process
		mockSpawn((mocked, command, args) => {
			spawned = mocked
			spawnCommand = command
			spawnArgs = args
		})

		// Mock fs
		jest.unstable_mockModule("fs", () =>
			mockFs((mocked) => {
				mockedFs = mocked
			}),
		)

		const { sendMessageToClaudeCode: sendMessageToClaudeCodeImpl } = await import("../sendMessageToClaudeCode")
		sendMessageToClaudeCode = sendMessageToClaudeCodeImpl
	})

	beforeEach(() => {
		res = new MockResponse()
		// Clear file system and mock call history between tests
		if (mockedFs) {
			mockedFs.restore()
		}
	})

	const createTestMessage = (text: string): Message => ({
		role: "user",
		content: [{ type: "text", text }],
	})

	const createTestLocalExecutable = (): LocalExecutable => ({
		executable: "/usr/local/bin/claude",
		env: { NODE_ENV: "test" },
		cwd: "/test/dir",
	})

	const simulateClaudeResponse = (message: string, sessionId: string = "test-session-123") => {
		spawned?.stdout.write(
			JSON.stringify({
				message: {
					content: [
						{
							type: "text",
							text: message,
						},
					],
				},
				session_id: sessionId,
				type: "assistant",
				parent_tool_use_id: null,
			} satisfies SDKMessage),
		)
		spawned?.stdout.end()
		spawned?.emit("close", 0)
	}

	const expectSessionIdAndTextResponse = (sessionId: string, text: string) => {
		expect(res.writtenData).toEqual([
			JSON.stringify({
				type: "internal_content",
				value: {
					type: "session_id",
					sessionId,
				},
				idx: 0,
			} satisfies StreamedResponseChunk),
			JSON.stringify({
				type: "text_delta",
				text: text + "\n",
				idx: 1,
			} satisfies StreamedResponseChunk),
		])
	}

	describe("basic functionality", () => {
		it("should process a simple message successfully", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Hello Claude")],
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			// Test spawn arguments
			expect(spawnCommand).toBe("/usr/local/bin/claude")
			expect(spawnArgs).toEqual([
				"--output-format",
				"stream-json",
				"--verbose",
				"--max-turns",
				"100",
				"--mcp-config",
				expect.stringContaining("mcp.json"),
				"--dangerously-skip-permissions",
			])

			expect(spawned?.stdin.read().toString()).toBe("Hello Claude")
			expect(mockedFs.writeFileSync).toHaveBeenCalledWith(
				expect.stringContaining("mcp.json"),
				expect.stringContaining('"url": "http://localhost:3000/mcp"'),
			)

			simulateClaudeResponse("Hello to you too!")
			await done

			expectSessionIdAndTextResponse("test-session-123", "Hello to you too!")
		})

		it("should handle multiple user messages correctly", async () => {
			const messages = [
				createTestMessage("First message"),
				createTestMessage("Second message"),
				createTestMessage("Third message"),
			]

			const done = sendMessageToClaudeCode(
				{
					messages,
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			expect(spawned?.stdin.read().toString()).toBe("First message\nSecond message\nThird message")

			simulateClaudeResponse("Processing multiple messages")
			await done

			expectSessionIdAndTextResponse("test-session-123", "Processing multiple messages")
		})
	})

	describe("session resumption", () => {
		it("should resume existing session when session_id is present", async () => {
			const messagesWithSession: Message[] = [
				{
					role: "assistant",
					content: [
						{
							type: "internal_content",
							value: {
								type: "session_id",
								sessionId: "existing-session-456",
							},
							idx: 0,
						},
					],
				},
				createTestMessage("Continue the conversation"),
			]

			const done = sendMessageToClaudeCode(
				{
					messages: messagesWithSession,
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			// Verify that --resume flag is passed with the session ID
			expect(spawnArgs).toEqual([
				"--output-format",
				"stream-json",
				"--verbose",
				"--max-turns",
				"100",
				"--mcp-config",
				expect.stringContaining("mcp.json"),
				"--dangerously-skip-permissions",
				"--resume",
				"existing-session-456",
			])
			expect(spawned?.stdin.read().toString()).toBe("Continue the conversation")

			simulateClaudeResponse("Continuing session", "existing-session-456")
			await done

			expectSessionIdAndTextResponse("existing-session-456", "Continuing session")
		})
	})

	describe("error handling", () => {
		it("should handle stderr output from claude process", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test error")],
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			// Trigger error asynchronously to allow stream consumer to start
			setImmediate(() => {
				spawned?.stderr.write("Claude error occurred")
			})

			await expect(done).rejects.toThrow("Failed to send message.")
		})

		it("should handle non-zero exit code", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test exit code")],
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			// Trigger error asynchronously to allow stream consumer to start
			setImmediate(() => {
				spawned?.emit("close", 1)
			})

			await expect(done).rejects.toThrow("Failed to send message.")
		})
	})

	describe("different message types", () => {
		it("should handle tool_use messages", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Use a tool")],
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			spawned?.stdout.write(
				JSON.stringify({
					message: {
						content: [
							{
								type: "tool_use",
								id: "tool_123",
								name: "read_file",
								input: { file_path: "/path/to/file.txt" },
							},
						],
					},
					session_id: "test-session-123",
					type: "assistant",
					parent_tool_use_id: null,
				} satisfies SDKMessage),
			)
			spawned?.stdout.end()
			spawned?.emit("close", 0)

			await done

			expect(res.writtenData).toEqual([
				JSON.stringify({
					type: "internal_content",
					value: {
						type: "session_id",
						sessionId: "test-session-123",
					},
					idx: 0,
				} satisfies StreamedResponseChunk),
				JSON.stringify({
					type: "tool_call",
					toolName: "claude_code_read_file",
					toolUseId: "tool_123",
					input: { file_path: "/path/to/file.txt" },
					idx: 1,
				} satisfies StreamedResponseChunk),
			])
		})

		it("should handle thinking messages", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Think about this")],
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			spawned?.stdout.write(
				JSON.stringify({
					message: {
						content: [
							{
								type: "thinking",
								thinking: "Let me think about this...",
							},
						],
					},
					session_id: "test-session-123",
					type: "assistant",
					parent_tool_use_id: null,
				} satisfies SDKMessage),
			)
			spawned?.stdout.end()
			spawned?.emit("close", 0)

			await done

			expect(res.writtenData).toEqual([
				JSON.stringify({
					type: "internal_content",
					value: {
						type: "session_id",
						sessionId: "test-session-123",
					},
					idx: 0,
				} satisfies StreamedResponseChunk),
				JSON.stringify({
					type: "reasoning_delta",
					delta: "Let me think about this...\n",
					idx: 1,
				} satisfies StreamedResponseChunk),
			])
		})

		it("should handle tool_result messages", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Tool result test")],
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			spawned?.stdout.write(
				JSON.stringify({
					message: {
						content: [
							{
								type: "tool_result",
								tool_use_id: "tool_123",
								content: "File contents here",
							},
						],
					},
					session_id: "test-session-123",
					type: "user",
					parent_tool_use_id: null,
				} satisfies SDKMessage),
			)
			spawned?.stdout.end()
			spawned?.emit("close", 0)

			await done

			expect(res.writtenData).toEqual([
				JSON.stringify({
					type: "internal_content",
					value: {
						type: "session_id",
						sessionId: "test-session-123",
					},
					idx: 0,
				} satisfies StreamedResponseChunk),
				JSON.stringify({
					type: "tool_result",
					toolUseId: "tool_123",
					toolName: "claude_code_tool",
					result: {
						type: "tool_result_success",
						success: "File contents here",
					},
					idx: 1,
				} satisfies StreamedResponseChunk),
			])
		})
	})

	describe("mcp configuration", () => {
		it("should create mcp.json with correct port configuration", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test MCP config")],
					localExecutable: createTestLocalExecutable(),
					port: 4567,
				},
				res as unknown as Response,
			)

			expect(mockedFs.writeFileSync).toHaveBeenCalledWith(
				expect.stringContaining("mcp.json"),
				expect.stringContaining('"url": "http://localhost:4567/mcp"'),
			)

			simulateClaudeResponse("MCP configured")
			await done
		})

		it("should have clean state between tests (mockFs restore test)", async () => {
			// This test verifies that mockFs.restore() works correctly
			// The files object should be empty at the start of each test
			expect(Object.keys(mockedFs.files)).toHaveLength(0)
			expect(mockedFs.writeFileSync).toHaveBeenCalledTimes(0)

			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test restore")],
					localExecutable: createTestLocalExecutable(),
					port: 8080,
				},
				res as unknown as Response,
			)

			// After the call, there should be one file created
			expect(mockedFs.writeFileSync).toHaveBeenCalledTimes(1)
			expect(Object.keys(mockedFs.files)).toHaveLength(1)

			simulateClaudeResponse("Restore test")
			await done
		})

		it("should handle Claude AI usage limit reached response", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test usage limit")],
					localExecutable: createTestLocalExecutable(),
					port: 3000,
				},
				res as unknown as Response,
			)

			// Simulate Claude usage limit response
			spawned?.stdout.write(
				JSON.stringify({
					type: "assistant",
					message: {
						content: [
							{
								type: "text",
								text: "Claude AI usage limit reached|1753938000",
							},
						],
					},
					parent_tool_use_id: null,
					session_id: "41184823-1c4b-4117-a10e-6bb9ba71c60c",
				}),
			)

			// Simulate result message
			spawned?.stdout.write(
				JSON.stringify({
					type: "result",
					subtype: "success",
					is_error: true,
					result: "Claude AI usage limit reached|1753938000",
					session_id: "41184823-1c4b-4117-a10e-6bb9ba71c60c",
				}),
			)

			spawned?.stdout.end()
			spawned?.emit("close", 0)

			await done

			expect(res.writtenData).toEqual([
				JSON.stringify({
					type: "internal_content",
					value: {
						type: "session_id",
						sessionId: "41184823-1c4b-4117-a10e-6bb9ba71c60c",
					},
					idx: 0,
				} satisfies StreamedResponseChunk),
				JSON.stringify({
					type: "error",
					message: "Claude AI usage limit reached. Your limit will reset at 10:00 PM PDT.",
					idx: 1,
				} satisfies StreamedResponseChunk),
			])
		})
	})
})
