import { describe, expect, it, jest, beforeEach } from "@jest/globals"
import { Response } from "express"
import { sendMessageToClaudeCode } from "../claudeCode/sendMessageToClaudeCode"
import { LocalExecutable } from "../../../schemas/sendMessageSchema"
import { CoreMessage } from "ai"
import { spawn } from "child_process"
import { EventEmitter } from "events"

// Mock the spawn function
jest.mock("child_process", () => ({
	spawn: jest.fn(),
}))

// Mock logger
jest.mock("@/logger", () => ({
	logInfo: jest.fn(),
	logError: jest.fn(),
}))

const mockSpawn = spawn as jest.Mock

describe("sendMessageToClaudeCode", () => {
	let mockResponse: Partial<Response>
	let mockChildProcess: any
	let localExecutable: LocalExecutable

	beforeEach(() => {
		mockResponse = {
			write: jest.fn().mockReturnValue(true) as any,
			end: jest.fn().mockReturnValue(mockResponse) as any,
			headersSent: false,
		}

		// Create a mock child process that extends EventEmitter
		mockChildProcess = new EventEmitter()
		mockChildProcess.stdin = {
			write: jest.fn(),
			end: jest.fn(),
		}
		mockChildProcess.stdout = new EventEmitter()
		mockChildProcess.stderr = new EventEmitter()
		mockChildProcess.pid = 12345
		mockChildProcess.kill = jest.fn()

		// Set encoding methods
		mockChildProcess.stdout.setEncoding = jest.fn()
		mockChildProcess.stderr.setEncoding = jest.fn()

		mockSpawn.mockReturnValue(mockChildProcess)

		localExecutable = {
			executable: "/path/to/claude",
			env: { NODE_ENV: "test" },
			cwd: "/test/dir",
		}

		jest.clearAllMocks()
	})

	it("should handle text messages from Claude assistant", async () => {
		const messages: CoreMessage[] = [
			{
				role: "user",
				content: "Hello Claude",
			},
		]

		// Mock Claude assistant message
		const claudeAssistantMessage = {
			type: "assistant",
			message: {
				id: "msg_123",
				type: "message",
				role: "assistant",
				content: [
					{
						type: "text",
						text: "Hello! How can I help you today?",
					},
				],
				model: "claude-3-5-sonnet-20241022",
				stop_reason: "end_turn",
				stop_sequence: null,
				usage: {
					input_tokens: 10,
					output_tokens: 15,
				},
			},
			parent_tool_use_id: null,
			session_id: "session_123",
		}

		const promise = sendMessageToClaudeCode(messages, localExecutable, mockResponse as Response)

		// Simulate Claude spawning successfully
		setTimeout(() => {
			mockChildProcess.emit("spawn")
		}, 10)

		// Simulate Claude sending a text message
		setTimeout(() => {
			mockChildProcess.stdout.emit("data", JSON.stringify(claudeAssistantMessage))
		}, 20)

		// Simulate process closing successfully
		setTimeout(() => {
			mockChildProcess.emit("close", 0)
		}, 30)

		await promise

		// Verify the assistant message was converted to TextDelta format
		const expectedTextDelta = {
			type: "text_delta",
			text: "Hello! How can I help you today?",
			idx: 0,
		}
		expect(mockResponse.write).toHaveBeenCalledWith(JSON.stringify(expectedTextDelta))
		expect(mockResponse.end).toHaveBeenCalled()
	})

	it("should ignore non-assistant messages", async () => {
		const messages: CoreMessage[] = [
			{
				role: "user",
				content: "Hello Claude",
			},
		]

		// Mock Claude system message (should be ignored)
		const claudeSystemMessage = {
			type: "system",
			subtype: "init",
			apiKeySource: "user",
			cwd: "/test",
			session_id: "session_123",
			tools: [],
			mcp_servers: [],
			model: "claude-3-5-sonnet-20241022",
			permissionMode: "default",
		}

		const promise = sendMessageToClaudeCode(messages, localExecutable, mockResponse as Response)

		// Simulate Claude spawning successfully
		setTimeout(() => {
			mockChildProcess.emit("spawn")
		}, 10)

		// Simulate Claude sending a system message (should be ignored)
		setTimeout(() => {
			mockChildProcess.stdout.emit("data", JSON.stringify(claudeSystemMessage))
		}, 20)

		// Simulate process closing successfully
		setTimeout(() => {
			mockChildProcess.emit("close", 0)
		}, 30)

		await promise

		// Verify no messages were written to response (since we're ignoring non-assistant messages for now)
		expect(mockResponse.write).not.toHaveBeenCalledWith(JSON.stringify(claudeSystemMessage))
		expect(mockResponse.end).toHaveBeenCalled()
	})

	it("should handle process errors", async () => {
		const messages: CoreMessage[] = [
			{
				role: "user",
				content: "Hello Claude",
			},
		]

		const promise = sendMessageToClaudeCode(messages, localExecutable, mockResponse as Response)

		// Simulate spawn error
		setTimeout(() => {
			mockChildProcess.emit("error", new Error("Failed to spawn"))
		}, 10)

		await expect(promise).rejects.toThrow("Failed to spawn")
	})
})
