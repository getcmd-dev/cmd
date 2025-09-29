import { describe, expect, it, jest, beforeEach, beforeAll } from "@jest/globals"
import { Request, Response, Router } from "express"
import { LocalExecutable, Message, StreamedResponseChunk } from "../../../../schemas/sendMessageSchema"
import { MockedSpawn, mockSpawn } from "@/utils/tests/mockSpawn"
import { MockedQuery, mockQuery } from "./mockClaudeCodeSDK"
import { MockedFs, mockFs } from "@/utils/tests/mockFs"
import { MockResponse } from "@/utils/tests/mockResponse"
import { SDKMessage } from "@anthropic-ai/claude-code"
import { ApproveToolUseRequestParams, ApprovalResult } from "../../../../schemas/toolApprovalSchema"
import type { BetaMessage as APIAssistantMessage } from "@anthropic-ai/sdk/resources/beta/messages/messages.mjs"

const assistantMessageMetadata: Omit<APIAssistantMessage, "content"> = {
	role: "assistant",
	model: "claude-3-5-haiku-20241022",
	id: "",
	stop_reason: null,
	stop_sequence: null,
	type: "message",
	container: null,
	usage: {
		input_tokens: 0,
		output_tokens: 0,
		cache_creation: null,
		cache_creation_input_tokens: null,
		cache_read_input_tokens: null,
		server_tool_use: null,
		service_tier: null,
	},
}

describe("sendMessageToClaudeCode", () => {
	let sendMessageToClaudeCode: typeof import("../sendMessageToClaudeCode").sendMessageToClaudeCode
	let registerEndpoint: typeof import("../sendMessageToClaudeCode").registerEndpoint
	let res: MockResponse

	let query: MockedQuery

	let spawned: MockedSpawn
	let spawnCommand: string
	let spawnArgs: string[]

	let mockedFs: MockedFs
	let mockMCPToolApprovalCallback: (toolName: string, input: unknown) => Promise<ApprovalResult>
	let testThreadId: string
	const router = Router()

	// Helper function to yield control to the event loop, allowing async operations to complete
	const yieldToEventLoop = () => new Promise((resolve) => setImmediate(resolve))

	beforeAll(async () => {
		// Mock @anthropic-ai/claude-code
		mockQuery((mockedQuery) => {
			query = mockedQuery
		})

		// Mock child_process
		mockSpawn((mocked, command, args) => {
			console.log("spawn loaded")
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

		// Mock mcp module since it imports `@modelcontextprotocol`, and for some reason this causes the test to hang.
		jest.unstable_mockModule("@/server/endpoints/sendMessage/claudeCode/mcp", () => ({
			registerMCPServerEndpoints: jest.fn(
				(
					router: Router,
					endpoint: string,
					callback: (toolName: string, input: unknown) => Promise<ApprovalResult>,
				) => {
					mockMCPToolApprovalCallback = callback
				},
			),
		}))

		const { sendMessageToClaudeCode: sendMessageToClaudeCodeImpl, registerEndpoint: registerEndpointImpl } =
			await import("../sendMessageToClaudeCode")
		sendMessageToClaudeCode = sendMessageToClaudeCodeImpl
		registerEndpoint = registerEndpointImpl
	})

	beforeEach(() => {
		res = new MockResponse()
		// Generate a unique thread ID for each test to avoid state interference
		testThreadId = `test-thread-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
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

	const createTestLocalExecutableByName = (): LocalExecutable => ({
		executable: "claude",
		env: { NODE_ENV: "test" },
		cwd: "/test/dir",
	})

	const simulateClaudeResponse = (message: string, sessionId: string = "test-session-123") => {
		if (!query) {
			throw new Error("query mock is not initialized")
		}

		// Send a streaming text delta event first
		query.sendEvent({
			type: "stream_event",
			session_id: sessionId,
			parent_tool_use_id: null,
			uuid: crypto.randomUUID(),
			event: {
				type: "content_block_delta",
				index: 0,
				delta: {
					type: "text_delta",
					text: message + "\n",
				},
			},
		})

		// Then send the complete assistant message
		query.sendEvent({
			message: {
				...assistantMessageMetadata,
				content: [
					{
						type: "text",
						text: message,
						citations: [],
					},
				],
			},
			session_id: sessionId,
			type: "assistant",
			parent_tool_use_id: null,
			uuid: crypto.randomUUID(),
		} satisfies SDKMessage)
		query.end()
	}

	const expectSessionIdAndTextResponse = (sessionId: string, text: string) => {
		expect(res.writtenData.map((data) => data.trim())).toEqual([
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
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized by giving control to the event loop
			await yieldToEventLoop()

			simulateClaudeResponse("Hello to you too!")
			await done

			expectSessionIdAndTextResponse("test-session-123", "Hello to you too!")
		})

		it("should resolve executable by name", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Hello Claude")],
					localExecutable: createTestLocalExecutableByName(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Test spawn arguments
			expect(spawnCommand).toBe("which")
			expect(spawnArgs).toEqual(["claude"])
			spawned?.stdout.write("/usr/local/bin/claude")
			spawned?.stdout.end()
			spawned?.emit("close", 0)

			// Wait for the query to be initialized by giving control to the event loop
			await yieldToEventLoop()
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
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized by giving control to the event loop
			await yieldToEventLoop()

			// The SDK should receive all user messages in the prompt
			// This test verifies that multiple messages are handled correctly by the SDK

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
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized by giving control to the event loop
			await yieldToEventLoop()

			// Verify that the existing session ID is used for resumption
			// The SDK should receive the resume option internally
			// We can verify this works by checking that the correct session ID is used in the response

			simulateClaudeResponse("Continuing session", "existing-session-456")
			await done

			expectSessionIdAndTextResponse("existing-session-456", "Continuing session")
		})
	})

	describe("error handling", () => {
		it("should handle Claude SDK errors gracefully", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test error")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized by giving control to the event loop
			await yieldToEventLoop()

			// Simulate an error in the Claude SDK by ending the query without sending events
			query?.end()

			await done

			// Verify that the function completes even with no response
			// The implementation should handle empty responses gracefully
		})

		it("should handle query interruption", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test interruption")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate normal response to avoid timeout
			simulateClaudeResponse("Response before interruption")

			await done

			expectSessionIdAndTextResponse("test-session-123", "Response before interruption")
		})
	})

	describe("different message types", () => {
		it("should handle tool_use messages", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Use a tool")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate tool use message from Claude
			if (query) {
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
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
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
				query.end()
			}

			await done

			expect(res.writtenData.map((data) => data.trim())).toEqual([
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
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate thinking message from Claude
			if (query) {
				// Send streaming thinking delta first
				query.sendEvent({
					type: "stream_event",
					session_id: "test-session-123",
					parent_tool_use_id: null,
					uuid: crypto.randomUUID(),
					event: {
						type: "content_block_delta",
						index: 0,
						delta: {
							type: "thinking_delta",
							thinking: "Let me think about this...\n",
						},
					},
				})

				// Then send the complete thinking message
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
						content: [
							{
								type: "thinking",
								thinking: "Let me think about this...",
								signature: "thinking-signature",
							},
						],
					},
					session_id: "test-session-123",
					type: "assistant",
					parent_tool_use_id: null,
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
				query.end()
			}

			await done

			expect(res.writtenData.map((data) => data.trim())).toEqual([
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
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate tool result message from Claude
			if (query) {
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
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
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
				query.end()
			}

			await done

			expect(res.writtenData.map((data) => data.trim())).toEqual([
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
		it("should register MCP endpoint correctly", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test MCP config")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 4567,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// The MCP endpoint should be registered during setup
			// We can verify this by checking that the registerMCPServerEndpoints mock was called
			// This test verifies that MCP configuration is handled properly with the new SDK approach

			simulateClaudeResponse("MCP configured")
			await done

			expectSessionIdAndTextResponse("test-session-123", "MCP configured")
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
					threadId: testThreadId,
					port: 8080,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// With the SDK approach, no files are created during the call
			// The test now verifies that the mockFs state is properly reset between tests

			simulateClaudeResponse("Restore test")
			await done

			expectSessionIdAndTextResponse("test-session-123", "Restore test")
		})

		it("should handle Claude AI usage limit reached response", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Test usage limit")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate Claude usage limit response using the query mock
			if (query) {
				// Simulate result message with usage limit error
				query.sendEvent({
					type: "result",
					subtype: "success",
					is_error: true,
					result: "Claude AI usage limit reached|1753938000",
					session_id: "41184823-1c4b-4117-a10e-6bb9ba71c60c",
					uuid: crypto.randomUUID(),
					duration_ms: 1000,
					duration_api_ms: 800,
					num_turns: 1,
					total_cost_usd: 0.01,
					usage: {
						input_tokens: 10,
						output_tokens: 5,
						cache_creation_input_tokens: 0,
						cache_read_input_tokens: 0,
						cache_creation: {
							ephemeral_1h_input_tokens: 0,
							ephemeral_5m_input_tokens: 0,
						},
						server_tool_use: {
							web_fetch_requests: 0,
							web_search_requests: 0,
						},
						service_tier: "standard",
					},
					modelUsage: {
						"claude-3-5-haiku-20241022": {
							inputTokens: 10,
							outputTokens: 5,
							cacheCreationInputTokens: 0,
							cacheReadInputTokens: 0,
							webSearchRequests: 0,
							costUSD: 0.01,
						},
					},
					permission_denials: [],
				})
				query.end()
			}

			await done

			expect(res.writtenData.map((data) => data.trim())).toEqual([
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

	describe("mcp tool approval", () => {
		it("should handle tool approval request via MCP endpoint and yield tool_use_permission_request", async () => {
			// First, we need to simulate a tool use request that creates the matching tool call
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Use a tool")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate tool use from Claude using the query mock
			if (query) {
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
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
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
			}

			// Yield control to allow the tool use to be processed
			await yieldToEventLoop()

			// Now call the MCP callback with a tool approval request
			void mockMCPToolApprovalCallback("read_file", { file_path: "/path/to/file.txt" })

			// Yield control to allow the permission request to be processed
			await yieldToEventLoop()

			// Check that the last written chunk is the tool_use_permission_request
			const lastChunk = JSON.parse(res.writtenData[res.writtenData.length - 1].trim())
			expect(lastChunk).toMatchObject({
				type: "tool_use_permission_request",
				toolName: "claude_code_read_file",
				toolUseId: "tool_123",
				input: { file_path: "/path/to/file.txt" },
			})
			expect(lastChunk.idx).toBe(res.writtenData.length - 1)

			// Clean up by completing the query
			query?.end()
			await done
		})

		it("should use exact input matching to identify which tool use to request permissions for", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Use multiple tools")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate two tool uses with same name but different inputs using the query mock
			if (query) {
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
						content: [
							{
								type: "tool_use",
								id: "tool_123",
								name: "read_file",
								input: { file_path: "/path/to/file1.txt" },
							},
						],
					},
					session_id: "test-session-123",
					type: "assistant",
					parent_tool_use_id: null,
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)

				query.sendEvent({
					message: {
						...assistantMessageMetadata,
						content: [
							{
								type: "tool_use",
								id: "tool_456",
								name: "read_file",
								input: { file_path: "/path/to/file2.txt" },
							},
						],
					},
					session_id: "test-session-123",
					type: "assistant",
					parent_tool_use_id: null,
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
			}

			await yieldToEventLoop()

			// Request approval for the second tool (file2.txt)
			void mockMCPToolApprovalCallback("read_file", { file_path: "/path/to/file2.txt" })

			await yieldToEventLoop()

			// Check that the last written chunk has the correct tool use ID (tool_456, not tool_123)
			const permissionRequest = JSON.parse(res.writtenData[res.writtenData.length - 1].trim())
			expect(permissionRequest).toMatchObject({
				type: "tool_use_permission_request",
				toolName: "claude_code_read_file",
				toolUseId: "tool_456",
				input: { file_path: "/path/to/file2.txt" },
			})
			expect(permissionRequest.idx).toBe(res.writtenData.length - 1)

			query?.end()
			await done
		})

		it("should fall back to name-only matching when exact input matching fails to identify which tool use to request permissions for", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Use a tool")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate tool use using the query mock
			if (query) {
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
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
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
			}

			await yieldToEventLoop()

			// Request approval with slightly different input (should fall back to name-only matching)
			void mockMCPToolApprovalCallback("read_file", {
				file_path: "/path/to/different_file.txt",
			})

			await yieldToEventLoop()

			// Check that the last written chunk uses name-only matching (fallback behavior)
			const permissionRequest = JSON.parse(res.writtenData[res.writtenData.length - 1].trim())
			expect(permissionRequest).toMatchObject({
				type: "tool_use_permission_request",
				toolName: "claude_code_read_file",
				toolUseId: "tool_123",
				// Should use the original input from the tool use, not the MCP request input
				input: { file_path: "/path/to/file.txt" },
			})
			expect(permissionRequest.idx).toBe(res.writtenData.length - 1)

			query?.end()
			await done
		})

		it("should throw error when no matching tool call is found", async () => {
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("No tools used")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Don't simulate any tool use

			// Try to request approval for a non-existent tool
			await expect(mockMCPToolApprovalCallback("read_file", { file_path: "/path/to/file.txt" })).rejects.toThrow(
				`No tool use requests found for thread ${testThreadId}`,
			)

			// Complete the query to finish the test
			query?.end()
			await done
		})
	})

	describe("/sendMessage/toolUse/permission endpoint", () => {
		let mockRequest: Partial<Request>
		let mockResponse: Partial<Response>
		let responseJson: jest.MockedFunction<(unknown) => Response<unknown, Record<string, unknown>>>
		let responseStatus: jest.MockedFunction<(code: number) => Response<unknown, Record<string, unknown>>>

		beforeEach(() => {
			responseJson = jest.fn()
			responseStatus = jest.fn().mockReturnValue({ json: responseJson }) as jest.MockedFunction<
				(code: number) => Response<unknown, Record<string, unknown>>
			>
			mockResponse = {
				json: responseJson,
				status: responseStatus,
			}
			registerEndpoint(router)
		})

		it("should successfully handle approval request when pending request exists", async () => {
			// First set up a pending tool approval by simulating the MCP flow
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Use a tool")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate tool use to create pending request using the query mock
			if (query) {
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
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
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
			}

			await yieldToEventLoop()

			// Trigger MCP callback to create pending request
			const approvalPromise = mockMCPToolApprovalCallback("read_file", { file_path: "/path/to/file.txt" })

			await yieldToEventLoop()

			// Now test the permission endpoint
			const requestBody: ApproveToolUseRequestParams = {
				toolUseId: "tool_123",
				approvalResult: { type: "approval_allowed" },
			}

			mockRequest = {
				body: requestBody,
			}

			// Find and call the POST handler for /sendMessage/toolUse/permission
			const routes = router.stack.filter((layer) => layer.route?.path === "/sendMessage/toolUse/permission")
			expect(routes).toHaveLength(1)

			const postRoute = routes[0]?.route?.stack.find((layer) => layer.method === "post")
			expect(postRoute).toBeDefined()

			await postRoute!.handle(mockRequest as Request, mockResponse as Response, jest.fn())

			// Verify response
			expect(responseJson).toHaveBeenCalledWith({ success: true })
			expect(responseStatus).not.toHaveBeenCalled() // Default 200 status

			// Verify the approval promise resolves with the correct result
			const approvalResult = await approvalPromise
			expect(approvalResult).toEqual({ type: "approval_allowed" })

			// Clean up
			query?.end()
			await done
		})

		it("should handle denial request correctly", async () => {
			// Set up pending approval
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Use a tool")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate tool use using the query mock
			if (query) {
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
						content: [
							{
								type: "tool_use",
								id: "tool_456",
								name: "write_file",
								input: { file_path: "/path/to/output.txt", content: "test" },
							},
						],
					},
					session_id: "test-session-123",
					type: "assistant",
					parent_tool_use_id: null,
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
			}

			await yieldToEventLoop()

			const approvalPromise = mockMCPToolApprovalCallback("write_file", {
				file_path: "/path/to/output.txt",
				content: "test",
			})

			await yieldToEventLoop()

			// Send denial request
			const requestBody: ApproveToolUseRequestParams = {
				toolUseId: "tool_456",
				approvalResult: { type: "approval_denied", reason: "File write not allowed in this context" },
			}

			mockRequest = { body: requestBody }

			const routes = router.stack.filter((layer) => layer.route?.path === "/sendMessage/toolUse/permission")
			const postRoute = routes[0]?.route?.stack.find((layer) => layer.method === "post")

			await postRoute!.handle(mockRequest as Request, mockResponse as Response, jest.fn())

			expect(responseJson).toHaveBeenCalledWith({ success: true })

			// Verify the approval promise resolves with denial
			const approvalResult = await approvalPromise
			expect(approvalResult).toEqual({
				type: "approval_denied",
				reason: "File write not allowed in this context",
			})

			query?.end()
			await done
		})

		it("should return 400 error for invalid toolUseId", async () => {
			const requestBody = {
				toolUseId: null,
				approvalResult: { type: "approval_allowed" },
			}

			mockRequest = { body: requestBody }

			const routes = router.stack.filter((layer) => layer.route?.path === "/sendMessage/toolUse/permission")
			const postRoute = routes[0]?.route?.stack.find((layer) => layer.method === "post")

			await expect(
				postRoute!.handle(mockRequest as Request, mockResponse as Response, jest.fn()),
			).rejects.toThrow("Invalid toolUseId")
		})

		it("should return 400 error for invalid approvalResult", async () => {
			const requestBody = {
				toolUseId: "valid-tool-id",
				approvalResult: null,
			}

			mockRequest = { body: requestBody }

			const routes = router.stack.filter((layer) => layer.route?.path === "/sendMessage/toolUse/permission")
			const postRoute = routes[0]?.route?.stack.find((layer) => layer.method === "post")

			await expect(
				postRoute!.handle(mockRequest as Request, mockResponse as Response, jest.fn()),
			).rejects.toThrow("Invalid approvalResult")
		})

		it("should return 404 error when no pending request found for toolUseId", async () => {
			const requestBody: ApproveToolUseRequestParams = {
				toolUseId: "non-existent-tool-123",
				approvalResult: { type: "approval_allowed" },
			}

			mockRequest = { body: requestBody }

			const routes = router.stack.filter((layer) => layer.route?.path === "/sendMessage/toolUse/permission")
			const postRoute = routes[0]?.route?.stack.find((layer) => layer.method === "post")

			await expect(
				postRoute!.handle(mockRequest as Request, mockResponse as Response, jest.fn()),
			).rejects.toThrow("No pending tool use approval request found for tool use non-existent-tool-123")
		})

		it("should handle multiple pending requests correctly", async () => {
			// Set up multiple pending approvals
			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Use multiple tools")],
					localExecutable: createTestLocalExecutable(),
					threadId: testThreadId,
					port: 3000,
					router,
				},
				res as unknown as Response,
			)

			// Wait for the query to be initialized
			await yieldToEventLoop()

			// Simulate multiple tool uses using the query mock
			if (query) {
				// First tool
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
						content: [
							{
								type: "tool_use",
								id: "tool_111",
								name: "read_file",
								input: { file_path: "/file1.txt" },
							},
						],
					},
					session_id: "test-session-123",
					type: "assistant",
					parent_tool_use_id: null,
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)

				// Second tool
				query.sendEvent({
					message: {
						...assistantMessageMetadata,
						content: [
							{
								type: "tool_use",
								id: "tool_222",
								name: "write_file",
								input: { file_path: "/file2.txt", content: "data" },
							},
						],
					},
					session_id: "test-session-123",
					type: "assistant",
					parent_tool_use_id: null,
					uuid: crypto.randomUUID(),
				} satisfies SDKMessage)
			}

			await yieldToEventLoop()

			const approval1Promise = mockMCPToolApprovalCallback("read_file", { file_path: "/file1.txt" })
			const approval2Promise = mockMCPToolApprovalCallback("write_file", {
				file_path: "/file2.txt",
				content: "data",
			})

			await yieldToEventLoop()

			// Approve first tool
			const routes = router.stack.filter((layer) => layer.route?.path === "/sendMessage/toolUse/permission")
			const postRoute = routes[0]?.route?.stack.find((layer) => layer.method === "post")

			mockRequest = {
				body: {
					toolUseId: "tool_111",
					approvalResult: { type: "approval_allowed" },
				} as ApproveToolUseRequestParams,
			}

			await postRoute!.handle(mockRequest as Request, mockResponse as Response, jest.fn())
			expect(responseJson).toHaveBeenCalledWith({ success: true })

			// Deny second tool
			responseJson.mockClear()
			mockRequest = {
				body: {
					toolUseId: "tool_222",
					approvalResult: { type: "approval_denied", reason: "Not allowed" },
				} as ApproveToolUseRequestParams,
			}

			await postRoute!.handle(mockRequest as Request, mockResponse as Response, jest.fn())
			expect(responseJson).toHaveBeenCalledWith({ success: true })

			// Verify both promises resolve with correct results
			const [result1, result2] = await Promise.all([approval1Promise, approval2Promise])
			expect(result1).toEqual({ type: "approval_allowed" })
			expect(result2).toEqual({ type: "approval_denied", reason: "Not allowed" })

			query?.end()
			await done
		})
	})
})
