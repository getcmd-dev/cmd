import { logError, logInfo } from "@/logger"
import * as acp from "@agentclientprotocol/sdk"

import { ACPClient } from "../ACPClient"
import { AsyncStream } from "@/utils/asyncStream"
import { spawn } from "child_process"
import { Readable, Writable } from "stream"

import { ACPToolCall } from "../../index"

export type GeminiCLIACPSessionInitializationParams = {
	cwd: string
	abortController?: AbortController
}

type SessionManager = {
	acpSessionId: string
	eventHandler?: AsyncStream<acp.SessionNotification>
	onPromptDone?: () => void
	permissionRequestHandler?: ({ toolCall, toolName }: { toolCall: ACPToolCall; toolName: string }) => Promise<boolean>
	interrupt: () => void
	prompt: (message: acp.ContentBlock[]) => void
}

export class GeminiCLIACPClient implements ACPClient<GeminiCLIACPSessionInitializationParams>, acp.Client {
	// keep track of active session to avoid creating multiple sessions
	private activeSessions: Record<string, SessionManager> = {}
	private readonly clientConnection: acp.ClientSideConnection
	private eventHandlerByACPSessionId: Record<string, (event: acp.SessionNotification) => void> = {}
	private permissionRequestHandlerByACPSessionId: Record<
		string,
		({ toolCall, toolName }: { toolCall: ACPToolCall; toolName: string }) => Promise<boolean>
	> = {}
	private spawnError?: Error

	constructor(executableInfo: { path: string; args: string[] }) {
		const agentPath = executableInfo.path

		// Set proxy if configured
		const env: NodeJS.ProcessEnv = {
			...process.env,
		}
		const geminiProxy = process.env.GEMINI_PROXY
		if (geminiProxy) {
			env["HTTP_PROXY"] = geminiProxy
		}

		// Spawn the agent as a subprocess
		logInfo(`spawning gemini process at ${agentPath} with args ${[...executableInfo.args, "--experimental-acp"]}`)
		const agentProcess = spawn(agentPath, [...executableInfo.args, "--experimental-acp"], {
			stdio: ["pipe", "pipe", "inherit"],
			env,
		})

		agentProcess.on("error", (err) => {
			this.spawnError = err
			logError(`Failed to spawn gemini process at ${agentPath}: ${err.message}`)
		})

		// Create streams to communicate with the agent
		const rawInput = Writable.toWeb(agentProcess.stdin!)
		const rawOutput = Readable.toWeb(agentProcess.stdout!) as ReadableStream<Uint8Array>

		// Wrap input stream to log everything written
		const inputLogger = new TransformStream<Uint8Array, Uint8Array>({
			transform: (chunk, controller) => {
				try {
					const text = new TextDecoder().decode(chunk)
					logInfo(`[GeminiCLIACPClient] Writing to input stream: ${text}`)
				} catch {
					logInfo(
						`[GeminiCLIACPClient] Writing to input stream (hex): ${Array.from(chunk)
							.map((b) => b.toString(16).padStart(2, "0"))
							.join(" ")}`,
					)
				}
				controller.enqueue(chunk)
			},
		})
		inputLogger.readable.pipeTo(rawInput).catch((err) => {
			logError(`[GeminiCLIACPClient] Error piping to input stream: ${err}`)
		})
		const input = inputLogger.writable

		// Wrap output stream to log everything read
		const outputLogger = new TransformStream<Uint8Array, Uint8Array>({
			transform: (chunk, controller) => {
				try {
					const text = new TextDecoder().decode(chunk)
					logInfo(`[GeminiCLIACPClient] Reading from output stream: ${text}`)
				} catch {
					logInfo(
						`[GeminiCLIACPClient] Reading from output stream (hex): ${Array.from(chunk)
							.map((b) => b.toString(16).padStart(2, "0"))
							.join(" ")}`,
					)
				}
				controller.enqueue(chunk)
			},
		})
		rawOutput.pipeTo(outputLogger.writable).catch((err) => {
			logError(`[GeminiCLIACPClient] Error piping from output stream: ${err}`)
		})
		const output = outputLogger.readable

		const stream = acp.ndJsonStream(input, output)

		this.clientConnection = new acp.ClientSideConnection((_agent) => this, stream)
	}

	async cancel(sessionId: string): Promise<void> {
		await this.clientConnection.cancel({
			sessionId,
		})
	}

	async prompt(
		sessionInitializationParams: GeminiCLIACPSessionInitializationParams,
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
		sessionInitializationParams: GeminiCLIACPSessionInitializationParams,
		threadId: string,
	): Promise<SessionManager> {
		if (this.spawnError) {
			throw new Error(`Cannot create session: gemini process failed to spawn - ${this.spawnError.message}`)
		}
		const abortController = sessionInitializationParams.abortController || new AbortController()
		// Initialize the connection
		await this.clientConnection.initialize({
			protocolVersion: acp.PROTOCOL_VERSION,
			clientCapabilities: {
				fs: {
					readTextFile: false,
					writeTextFile: false,
				},
				terminal: false,
			},
		})

		// Create a new session
		const sessionResult = await this.clientConnection.newSession({
			cwd: sessionInitializationParams.cwd,
			mcpServers: [],
		})
		// TODO: also support read-only?
		// await this.clientConnection.setSessionMode({
		// 	sessionId: sessionResult.sessionId,
		// 	modeId: "auto",
		// })
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
					`[GeminiCLIACPClient] No event handler found for session ${acpSessionId}. Starting new session.
					Event: ${JSON.stringify(event, null, 2)}.`,
				)
			}
		}
		this.permissionRequestHandlerByACPSessionId[acpSessionId] = ({ toolCall, toolName }) => {
			if (sessionManager.permissionRequestHandler) {
				return sessionManager.permissionRequestHandler({ toolCall, toolName })
			}
			logError(`[GeminiCLIACPClient] No permission request handler found for session ${acpSessionId}.`)
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
				`[GeminiCLIACPClient] Requesting permission for tool call: ${JSON.stringify(params.toolCall, null, 2)}`,
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
				`[GeminiCLIACPClient] No permission request handler found for session ${params.sessionId}.
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
		const handler = this.eventHandlerByACPSessionId[params.sessionId]
		if (handler) {
			handler(params)
		} else {
			logError(
				`[GeminiCLIACPClient] No event handler found for session ${params.sessionId}.
				Event: ${JSON.stringify(params, null, 2)}.`,
			)
		}
	}
}
