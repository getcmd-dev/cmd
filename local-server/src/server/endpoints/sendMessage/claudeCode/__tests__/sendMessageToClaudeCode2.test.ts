import { describe, expect, it, jest, beforeEach, beforeAll } from "@jest/globals"
import { Response } from "express"
import { LocalExecutable, Message } from "../../../../schemas/sendMessageSchema"
import { MockResponse } from "@/utils/tests/mockResponse"
import * as acp from "@agentclientprotocol/sdk"
import { AsyncStream } from "@/utils/asyncStream"

describe("sendMessageToClaudeCode2", () => {
	let sendMessageToClaudeCode: typeof import("../sendMessageToCodex").sendMessageToClaudeCode
	let res: MockResponse
	let testThreadId: string

	// Mock ClaudeAcpAgent
	type SessionInitParams = {
		pathToClaudeCodeExecutable: string
		cwd: string
		disallowedTools: string[]
		resume?: string
		env?: Record<string, string>
		abortController?: AbortController
		executableArgs?: string[]
		stderr?: (data: string) => void
	}

	type PermissionRequestHandler = ({
		toolCallId,
		input,
		toolName,
	}: {
		toolCallId: string
		input: unknown
		toolName: string
	}) => Promise<boolean>

	let mockPrompt: jest.MockedFunction<
		(
			sessionInitializationParams: SessionInitParams,
			message: acp.ContentBlock[],
			threadId: string,
			permissionRequestHandler: PermissionRequestHandler,
		) => Promise<AsyncIterable<acp.SessionNotification>>
	>

	// Helper function to yield control to the event loop
	const yieldToEventLoop = () => new Promise((resolve) => setImmediate(resolve))

	beforeAll(async () => {
		// Mock the ClaudeAcpAgent
		mockPrompt = jest.fn()

		jest.unstable_mockModule("@/server/endpoints/sendMessage/acp/clients/claudeCode/claudeCodeACPClient", () => ({
			ClaudeCodeACPClient: class MockClaudeCodeACPClient {
				async prompt(
					sessionInitializationParams: SessionInitParams,
					message: acp.ContentBlock[],
					threadId: string,
					permissionRequestHandler: PermissionRequestHandler,
				): Promise<AsyncIterable<acp.SessionNotification>> {
					return mockPrompt(sessionInitializationParams, message, threadId, permissionRequestHandler)
				}
			},
		}))

		// Mock the query function from Claude Agent SDK (used for nameConversation)
		// This is needed because nameConversation is called as a fire-and-forget operation
		// when starting a new session (when existingSessionId is undefined)
		type MockQueryResult = {
			supportedModels: () => Promise<Array<{ value: string }>>
			setModel: (model: string) => Promise<void>
			next: () => Promise<{ value: undefined; done: boolean }>
		}

		jest.unstable_mockModule("@anthropic-ai/claude-agent-sdk", () => ({
			query: jest.fn<() => MockQueryResult>().mockReturnValue({
				supportedModels: jest
					.fn<() => Promise<Array<{ value: string }>>>()
					.mockResolvedValue([{ value: "claude-3-haiku-20241022" }]),
				setModel: jest.fn<(model: string) => Promise<void>>().mockResolvedValue(undefined),
				next: jest
					.fn<() => Promise<{ value: undefined; done: boolean }>>()
					.mockResolvedValue({ value: undefined, done: true }),
			}),
		}))

		// Mock sendCommandToHostApp
		jest.unstable_mockModule("@/server/endpoints/interProcessesBridge", () => ({
			sendCommandToHostApp: jest.fn(),
		}))

		const { sendMessageToClaudeCode: sendMessageToClaudeCodeImpl } = await import("../sendMessageToCodex")
		sendMessageToClaudeCode = sendMessageToClaudeCodeImpl
	})

	beforeEach(() => {
		res = new MockResponse()
		testThreadId = `test-thread-${Date.now()}-${Math.random().toString(36).substring(2, 11)}_`
		mockPrompt.mockClear()
	})

	const createTestMessage = (text: string): Message => ({
		role: "user",
		content: [{ type: "text", text }],
	})

	const mockLocalExecutable: LocalExecutable = {
		executable: "/usr/local/bin/claude",
		env: { NODE_ENV: "test" },
		cwd: "/test/dir",
	}

	const createMockEventStream = (events: acp.SessionNotification[]): AsyncIterable<acp.SessionNotification> => {
		const stream = new AsyncStream<acp.SessionNotification>()

		// Yield events asynchronously
		setImmediate(() => {
			for (const event of events) {
				stream.yield(event)
			}
			stream.done()
		})

		return stream
	}

	describe("basic functionality", () => {
		it("should process a simple message successfully with ACP client", async () => {
			// Create mock events that simulate a successful response
			const mockEvents: acp.SessionNotification[] = [
				{
					sessionId: "test-session-123",
					_meta: {
						externalSessionId: "test-session-123",
					},
					update: {
						sessionUpdate: "agent_message_chunk",
						content: {
							type: "text",
							text: "Hello to you too!",
						},
					},
				},
			]

			mockPrompt.mockResolvedValue(createMockEventStream(mockEvents))

			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Hello Claude")],
					localExecutable: mockLocalExecutable,
					threadId: testThreadId,
					tools: [],
				},
				res as unknown as Response,
			)

			// Wait for the prompt to be called and processed
			await yieldToEventLoop()
			await yieldToEventLoop()

			await done

			// Verify that the ACP client's prompt method was called
			expect(mockPrompt).toHaveBeenCalledTimes(1)
			expect(mockPrompt).toHaveBeenCalledWith(
				expect.objectContaining({
					pathToClaudeCodeExecutable: "/usr/local/bin/claude",
					cwd: "/test/dir",
					disallowedTools: expect.arrayContaining([
						"Glob",
						"TodoWrite",
						"WebFetch",
						"WebSearch",
						"Edit",
						"MultiEdit",
						"Write",
						"Bash",
						"LS",
						"Read",
						"Grep",
					]),
				}),
				expect.arrayContaining([
					expect.objectContaining({
						type: "text",
						text: "Hello Claude",
					}),
				]),
				testThreadId,
				expect.any(Function), // permissionRequestHandler
			)

			// Verify the response contains session_id and text delta
			const writtenChunks = res.writtenData.map((data) => JSON.parse(data.trim()))
			expect(writtenChunks).toContainEqual(
				expect.objectContaining({
					type: "internal_content",
					value: {
						type: "session_id",
						sessionId: "test-session-123",
					},
				}),
			)
			expect(writtenChunks).toContainEqual(
				expect.objectContaining({
					type: "text_delta",
					text: "Hello to you too!",
				}),
			)
		})

		it("should handle tool use events from ACP", async () => {
			const mockEvents: acp.SessionNotification[] = [
				{
					sessionId: "test-session-456",
					_meta: {
						externalSessionId: "test-session-456",
					},
					update: {
						sessionUpdate: "tool_call",
						toolCallId: "tool_123",
						title: "Reading file",
						_meta: {
							toolName: "Read",
							input: { file_path: "/path/to/file.txt" },
						},
					},
				},
			]

			mockPrompt.mockResolvedValue(createMockEventStream(mockEvents))

			const done = sendMessageToClaudeCode(
				{
					messages: [createTestMessage("Read a file")],
					localExecutable: mockLocalExecutable,
					threadId: testThreadId,
					tools: [],
				},
				res as unknown as Response,
			)

			await yieldToEventLoop()
			await yieldToEventLoop()

			await done

			// Verify the response contains tool_call
			const writtenChunks = res.writtenData.map((data) => JSON.parse(data.trim()))
			expect(writtenChunks).toContainEqual(
				expect.objectContaining({
					type: "tool_call",
					toolName: "Read",
					toolUseId: "tool_123",
				}),
			)
		})

		it("should resume existing session when session_id is present in messages", async () => {
			const messagesWithSession: Message[] = [
				{
					role: "assistant",
					content: [
						{
							type: "internal_content",
							value: {
								type: "session_id",
								sessionId: "existing-session-789",
							},
							idx: 0,
						},
					],
				},
				createTestMessage("Continue the conversation"),
			]

			const mockEvents: acp.SessionNotification[] = [
				{
					sessionId: "existing-session-789",
					_meta: {
						externalSessionId: "existing-session-789",
					},
					update: {
						sessionUpdate: "agent_message_chunk",
						content: {
							type: "text",
							text: "Continuing session",
						},
					},
				},
			]

			mockPrompt.mockResolvedValue(createMockEventStream(mockEvents))

			const done = sendMessageToClaudeCode(
				{
					messages: messagesWithSession,
					localExecutable: mockLocalExecutable,
					threadId: testThreadId,
					tools: [],
				},
				res as unknown as Response,
			)

			await yieldToEventLoop()
			await yieldToEventLoop()

			await done

			// Verify that resume parameter was passed
			expect(mockPrompt).toHaveBeenCalledWith(
				expect.objectContaining({
					resume: "existing-session-789",
				}),
				expect.any(Array),
				testThreadId,
				expect.any(Function),
			)

			// Verify the response uses the existing session ID
			const writtenChunks = res.writtenData.map((data) => JSON.parse(data.trim()))
			expect(writtenChunks).toContainEqual(
				expect.objectContaining({
					type: "internal_content",
					value: {
						type: "session_id",
						sessionId: "existing-session-789",
					},
				}),
			)
		})
	})
})
