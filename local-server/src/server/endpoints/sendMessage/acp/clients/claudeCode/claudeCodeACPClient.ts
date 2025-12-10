import { logError, logInfo } from "@/logger"
import * as acp from "@agentclientprotocol/sdk"
import { ClaudeAcpAgent } from "../../claude-code-acp/index"

import { ClaudeAgentMeta } from "../../claude-code-acp/acp-agent"
import { Options } from "@anthropic-ai/claude-agent-sdk"
import { ACPClient } from "../ACPClient"
import { AsyncStream } from "@/utils/asyncStream"
import { withParsedToolCalls } from "./helper"
import { ACPToolCall } from "../.."

export type NewClaudeCodeACPSessionParams = {
	cwd: string
} & Options

type SessionManager = {
	acpSessionId: string
	eventHandler?: AsyncStream<acp.SessionNotification>
	onPromptDone?: () => void
	permissionRequestHandler?: ({ toolCall, toolName }: { toolCall: ACPToolCall; toolName: string }) => Promise<boolean>
	interrupt: () => void
	prompt: (message: acp.ContentBlock[]) => void
}

export class ClaudeCodeACPClient implements ACPClient<NewClaudeCodeACPSessionParams>, acp.Client {
	private readonly agentOutputStream = new TransformStream<acp.AnyMessage, acp.AnyMessage>()
	private readonly agentInputStream = new TransformStream<acp.AnyMessage, acp.AnyMessage>()
	// keep track of active session to avoid creating multiple sessions
	private activeSessions: Record<string, SessionManager> = {}
	private readonly clientConnection: acp.ClientSideConnection
	private readonly agentSideConnection: acp.AgentSideConnection
	private eventHandlerByACPSessionId: Record<string, (event: acp.SessionNotification) => void> = {}
	private permissionRequestHandlerByACPSessionId: Record<
		string,
		({ toolCall, toolName }: { toolCall: ACPToolCall; toolName: string }) => Promise<boolean>
	> = {}

	constructor() {
		this.clientConnection = new acp.ClientSideConnection((_agent) => this, {
			writable: this.agentInputStream.writable,
			readable: this.agentOutputStream.readable,
		})

		this.agentSideConnection = new acp.AgentSideConnection(
			(agentConnection) => new ClaudeAcpAgent(agentConnection, { log: logInfo, error: logError }),
			{
				writable: this.agentOutputStream.writable,
				readable: this.agentInputStream.readable,
			},
		)
	}

	async cancel(sessionId: string): Promise<void> {
		await this.clientConnection.cancel({
			sessionId,
		})
	}

	async prompt(
		newSessionParams: NewClaudeCodeACPSessionParams,
		message: acp.ContentBlock[],
		threadId: string,
		permissionRequestHandler: ({
			toolCall,
			toolName,
		}: {
			toolCall: ACPToolCall
			toolName: string
		}) => Promise<boolean>,
	): Promise<{ events: AsyncIterable<acp.SessionNotification>; sessionId: string }> {
		const session = this.activeSessions[threadId] || (await this.createSession(newSessionParams, threadId))

		const eventStream = new AsyncStream<acp.SessionNotification>()

		session.onPromptDone?.()
		session.onPromptDone = () => {
			eventStream.done()
		}
		session.eventHandler = eventStream
		session.permissionRequestHandler = permissionRequestHandler
		session.prompt(message)

		return { events: withParsedToolCalls(eventStream), sessionId: session.acpSessionId }
	}

	private async createSession(
		newSessionParams: NewClaudeCodeACPSessionParams,
		threadId: string,
	): Promise<SessionManager> {
		const abortController = newSessionParams.abortController || new AbortController()
		const meta: ClaudeAgentMeta = { options: { ...newSessionParams, abortController } }
		// Initialize the connection
		await this.clientConnection.initialize({
			protocolVersion: acp.PROTOCOL_VERSION,
			clientCapabilities: {},
			_meta: meta,
		})

		// Create a new session
		const sessionResult = await this.clientConnection.newSession({
			cwd: newSessionParams.cwd,
			mcpServers: [],
			_meta: meta,
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
					`[ClaudeCodeACPClient] No event handler found for session ${acpSessionId}.
					Event: ${JSON.stringify(event, null, 2)}.`,
				)
			}
		}
		this.permissionRequestHandlerByACPSessionId[acpSessionId] = ({ toolCall, toolName }) => {
			if (sessionManager.permissionRequestHandler) {
				return sessionManager.permissionRequestHandler({ toolCall, toolName })
			}
			logError(`[ClaudeCodeACPClient] No permission request handler found for session ${acpSessionId}.`)
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
			logInfo(
				`[ClaudeCodeACPClient] Requesting permission for tool call: ${JSON.stringify(params.toolCall, null, 2)}.
				Tool name: ${(params.toolCall._meta?.toolName as string) || `acp_${params.toolCall.kind!}`}`,
			)
			const isApproved = await permissionRequestHandler({
				toolCall: params.toolCall,
				toolName: (params.toolCall._meta?.toolName as string) || `acp_${params.toolCall.kind!}`,
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
				`[ClaudeCodeACPClient] No permission request handler found for session ${params.sessionId}.
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
		logInfo(`[ClaudeCodeACPClient] Session ${params.sessionId} update: ${JSON.stringify(params, null, 2)}`)
		const handler = this.eventHandlerByACPSessionId[params.sessionId]
		if (handler) {
			handler(params)
		} else {
			logError(
				`[ClaudeCodeACPClient] No event handler found for session ${params.sessionId}.
				Event: ${JSON.stringify(params, null, 2)}.`,
			)
		}
	}
}
