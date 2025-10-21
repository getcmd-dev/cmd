import { logError, logInfo } from "@/logger"
import * as acp from "@agentclientprotocol/sdk"

import { Options } from "@anthropic-ai/claude-agent-sdk"
import { ACPClient } from "../ACPClient"
import { AsyncStream } from "@/utils/asyncStream"
import { spawn } from "child_process"
import { Readable, Writable } from "stream"

export type CodexACPSessionInitializationParams = {
	cwd: string
} & Options

type SessionManager = {
	acpSessionId: string
	eventHandler?: AsyncStream<acp.SessionNotification>
	onPromptDone?: () => void
	permissionRequestHandler?: ({
		toolCallId,
		input,
		toolName,
	}: {
		toolCallId: string
		input: unknown
		toolName: string
	}) => Promise<boolean>
	interrupt: () => void
	prompt: (message: acp.ContentBlock[]) => void
}

export class CodexACPClient implements ACPClient<CodexACPSessionInitializationParams>, acp.Client {
	// keep track of active session to avoid creating multiple sessions
	private activeSessions: Record<string, SessionManager> = {}
	private readonly clientConnection: acp.ClientSideConnection
	private eventHandlerByACPSessionId: Record<string, (event: acp.SessionNotification) => void> = {}
	private permissionRequestHandlerByACPSessionId: Record<
		string,
		({ toolCallId, input, toolName }: { toolCallId: string; input: unknown; toolName: string }) => Promise<boolean>
	> = {}

	constructor() {
		const agentPath = "/Users/guigui/Downloads/codex-acp"

		// npx @zed-industries/codex-acp

		// Spawn the agent as a subprocess using tsx
		const agentProcess = spawn(agentPath, {
			stdio: ["pipe", "pipe", "inherit"],
		})
		// const agentProcess = spawn("npx", ["@zed-industries/codex-acp"], {
		// 	stdio: ["pipe", "pipe", "inherit"],
		// })

		// Create streams to communicate with the agent
		const input = Writable.toWeb(agentProcess.stdin!)
		const output = Readable.toWeb(agentProcess.stdout!) as ReadableStream<Uint8Array>
		const stream = acp.ndJsonStream(input, output)

		this.clientConnection = new acp.ClientSideConnection((_agent) => this, stream)
		// this.clientConnection.cancel({
		// 	sessionId: "123",
		// })
	}

	async cancel(sessionId: string): Promise<void> {
		await this.clientConnection.cancel({
			sessionId,
		})
	}

	async prompt(
		sessionInitializationParams: CodexACPSessionInitializationParams,
		message: acp.ContentBlock[],
		threadId: string,
		permissionRequestHandler: ({
			toolCallId,
			input,
			toolName,
		}: {
			toolCallId: string
			input: unknown
			toolName: string
		}) => Promise<boolean>,
	): Promise<{ events: AsyncIterable<acp.SessionNotification>; sessionId: string }> {
		const session =
			this.activeSessions[threadId] || (await this.createSession(sessionInitializationParams, threadId))

		const eventStream = new AsyncStream<acp.SessionNotification>()

		session.onPromptDone?.()
		session.onPromptDone = () => {
			eventStream.done()
		}
		session.eventHandler = eventStream
		session.permissionRequestHandler = permissionRequestHandler
		session.prompt(message)

		return { events: eventStream, sessionId: session.acpSessionId }
	}

	private async createSession(
		sessionInitializationParams: CodexACPSessionInitializationParams,
		threadId: string,
	): Promise<SessionManager> {
		const abortController = sessionInitializationParams.abortController || new AbortController()
		// Initialize the connection
		await this.clientConnection.initialize({
			protocolVersion: acp.PROTOCOL_VERSION,
			clientCapabilities: {},
		})

		// Create a new session
		const sessionResult = await this.clientConnection.newSession({
			cwd: sessionInitializationParams.cwd,
			mcpServers: [],
		})
		const acpSessionId = sessionResult.sessionId

		const sessionManager: SessionManager = {
			acpSessionId,
			prompt: async (message: acp.ContentBlock[]) => {
				try {
					await this.clientConnection.prompt({
						sessionId: acpSessionId,
						prompt: message,
					})
				} finally {
					this.activeSessions[threadId]?.onPromptDone?.()
				}
			},
			interrupt: abortController.abort,
		}
		this.activeSessions[threadId] = sessionManager

		this.eventHandlerByACPSessionId[acpSessionId] = (event) => {
			if (sessionManager.eventHandler) {
				sessionManager.eventHandler.yield(event)
			} else {
				logError(
					`[CodexACPClient] No event handler found for session ${acpSessionId}.
					Event: ${JSON.stringify(event, null, 2)}.`,
				)
			}
		}
		this.permissionRequestHandlerByACPSessionId[acpSessionId] = ({ toolCallId, input, toolName }) => {
			if (sessionManager.permissionRequestHandler) {
				return sessionManager.permissionRequestHandler({ toolCallId, input, toolName })
			}
			logError(
				`[CodexACPClient] No permission request handler found for session ${acpSessionId}.
				Tool call ID: ${toolCallId}.
				Tool input: ${JSON.stringify(input, null, 2)}.`,
			)
			return Promise.resolve(false)
		}

		return sessionManager
	}

	async requestPermission(params: acp.RequestPermissionRequest): Promise<acp.RequestPermissionResponse> {
		const allowOption = params.options.find((opt) => opt.kind === "allow_once")
		const rejectOption = params.options.find((opt) => opt.kind === "reject_once")
		if (!allowOption) {
			throw new Error("Missing allow option")
		}
		if (!rejectOption) {
			throw new Error("Missing reject option")
		}

		const permissionRequestHandler = this.permissionRequestHandlerByACPSessionId[params.sessionId]
		if (permissionRequestHandler) {
			logInfo(`[CodexACPClient] Requesting permission for tool call: ${JSON.stringify(params.toolCall, null, 2)}`)
			const isApproved = await permissionRequestHandler({
				toolCallId: params.toolCall.toolCallId,
				input: params.toolCall.rawInput,
				toolName: (params.toolCall._meta?.toolName as string) || params.toolCall.kind!,
			})
			if (isApproved) {
				return {
					outcome: {
						outcome: "selected",
						optionId: allowOption.optionId,
					},
				}
			} else {
				return {
					outcome: {
						outcome: "selected",
						optionId: rejectOption.optionId,
					},
				}
			}
		} else {
			logError(
				`[CodexACPClient] No permission request handler found for session ${params.sessionId}.
				Tool call ID: ${params.toolCall.toolCallId}.
				Tool input: ${JSON.stringify(params.toolCall, null, 2)}.`,
			)

			return {
				outcome: {
					outcome: "selected",
					optionId: rejectOption.optionId,
				},
			}
		}
	}

	async sessionUpdate(params: acp.SessionNotification): Promise<void> {
		logInfo(`[CodexACPClient] Session ${params.sessionId} update: ${JSON.stringify(params, null, 2)}`)
		const handler = this.eventHandlerByACPSessionId[params.sessionId]
		if (handler) {
			handler(params)
		} else {
			logError(
				`[CodexACPClient] No event handler found for session ${params.sessionId}.
				Event: ${JSON.stringify(params, null, 2)}.`,
			)
		}
	}
}
