import {
	Agent,
	AgentSideConnection,
	AuthenticateRequest,
	AvailableCommand,
	CancelNotification,
	ClientCapabilities,
	InitializeRequest,
	InitializeResponse,
	ndJsonStream,
	NewSessionRequest,
	NewSessionResponse,
	PromptRequest,
	PromptResponse,
	ReadTextFileRequest,
	ReadTextFileResponse,
	RequestError,
	SessionModelState,
	SetSessionModelRequest,
	SetSessionModelResponse,
	SetSessionModeRequest,
	SetSessionModeResponse,
	TerminalHandle,
	TerminalOutputResponse,
	WriteTextFileRequest,
	WriteTextFileResponse,
} from "@agentclientprotocol/sdk"
import {
	McpServerConfig,
	Options,
	PermissionMode,
	Query,
	query,
	SDKAssistantMessage,
	SDKPartialAssistantMessage,
	SDKUserMessage,
	SDKUserMessageReplay,
} from "@anthropic-ai/claude-agent-sdk"
import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { v7 as uuidv7 } from "uuid"
import { nodeToWebReadable, nodeToWebWritable, Pushable, unreachable } from "./utils"
import { SessionNotification } from "@agentclientprotocol/sdk"
import { createMcpServer, createPermissionMcpServer, PERMISSION_TOOL_NAME, toolNames } from "./mcp-server"
import { AddressInfo } from "node:net"
import {
	toolInfoFromToolUse,
	planEntries,
	toolUpdateFromToolResult,
	ClaudePlanEntry,
	preToolUseHook,
	postToolUseHook,
	registerHookCallback,
} from "./tools"
import { ToolResultBlockParam } from "@anthropic-ai/sdk/resources"
import { logError, logInfo } from "@/logger"

type Session = {
	query: Query
	input: Pushable<SDKUserMessage>
	cancelled: boolean
	permissionMode: PermissionMode
	claudeCodeSessionId?: string
}

type BackgroundTerminal =
	| {
			handle: TerminalHandle
			status: "started"
			lastOutput: TerminalOutputResponse | null
	  }
	| {
			status: "aborted" | "exited" | "killed" | "timedOut"
			pendingOutput: TerminalOutputResponse
	  }

type ToolUseCache = {
	[key: string]: CachedToolUse
}

export type CachedToolUse = {
	type: "tool_use"
	id: string
	name: string
	input: unknown
	toolResponse?: unknown
	output?: ToolResultBlockParam
}

const DEFAULT_MODEL_ID = "default"

export type ClaudeAgentMeta = {
	systemPrompt?: Options["systemPrompt"]
	options?: Options
}

export type ACPLogger = Pick<Console, "log" | "error">

export let acpLogger: ACPLogger = console

// Implement the ACP Agent interface
export class ClaudeAcpAgent implements Agent {
	sessions: {
		[key: string]: Session
	}
	client: AgentSideConnection
	toolUseCache: ToolUseCache
	fileContentCache: { [key: string]: string }
	backgroundTerminals: { [key: string]: BackgroundTerminal } = {}
	clientCapabilities?: ClientCapabilities
	logger: ACPLogger

	constructor(client: AgentSideConnection, logger: ACPLogger = console) {
		this.sessions = {}
		this.client = client
		this.toolUseCache = {}
		this.fileContentCache = {}
		this.logger = logger
		acpLogger = logger
	}

	async initialize(request: InitializeRequest): Promise<InitializeResponse> {
		this.clientCapabilities = request.clientCapabilities
		return {
			protocolVersion: 1,
			// todo!()
			agentCapabilities: {
				promptCapabilities: {
					image: true,
					embeddedContext: true,
				},
				mcpCapabilities: {
					http: true,
					sse: true,
				},
			},
			authMethods: [
				{
					description: "Run `claude /login` in the terminal",
					name: "Log in with Claude Code",
					id: "claude-login",
				},
			],
		}
	}
	async newSession(params: NewSessionRequest): Promise<NewSessionResponse> {
		if (
			fs.existsSync(path.resolve(os.homedir(), ".claude.json.backup")) &&
			!fs.existsSync(path.resolve(os.homedir(), ".claude.json"))
		) {
			throw RequestError.authRequired()
		}

		const meta = params._meta as ClaudeAgentMeta | undefined

		const sessionId = uuidv7()
		const input = new Pushable<SDKUserMessage>()

		const mcpServers: Record<string, McpServerConfig> = {}
		if (Array.isArray(params.mcpServers)) {
			for (const server of params.mcpServers) {
				if ("type" in server) {
					mcpServers[server.name] = {
						type: server.type,
						url: server.url,
						headers: server.headers
							? Object.fromEntries(server.headers.map((e) => [e.name, e.value]))
							: undefined,
					}
				} else {
					mcpServers[server.name] = {
						type: "stdio",
						command: server.command,
						args: server.args,
						env: server.env ? Object.fromEntries(server.env.map((e) => [e.name, e.value])) : undefined,
					}
				}
			}
		}

		const server = createMcpServer(this, sessionId, this.clientCapabilities)
		mcpServers["acp"] = {
			type: "sdk",
			name: "acp",
			instance: server,
		}

		// Ideally replace with `canUseTool`
		const permissionServer = await createPermissionMcpServer(this, sessionId)
		const address = permissionServer.address() as AddressInfo
		mcpServers["acpPermission"] = {
			type: "http",
			url: "http://127.0.0.1:" + address.port + "/mcp",
			headers: {
				"x-acp-proxy-session-id": sessionId,
			},
		}

		let systemPrompt: Options["systemPrompt"] = { type: "preset", preset: "claude_code" }
		if (meta?.systemPrompt) {
			const customPrompt = meta.systemPrompt
			if (typeof customPrompt === "string") {
				systemPrompt = customPrompt
			} else if (
				typeof customPrompt === "object" &&
				"append" in customPrompt &&
				typeof customPrompt.append === "string"
			) {
				systemPrompt.append = customPrompt.append
			}
		}

		const options = meta?.options
		const newOptions: Options = {
			systemPrompt,
			settingSources: ["user", "project", "local"],
			stderr: (err) => this.logger.error("Claude Code error", err),
			...options,
			// It seems that Claude Code doesn't cancels cleanly when the abort controller passed as an option
			// aborts.
			// So instead, we manually listen for the abort event and interrupt the query if that happens.
			abortController: undefined,
			cwd: params.cwd,
			mcpServers: { ...(options?.mcpServers || {}), ...mcpServers },
			// If we want bypassPermissions to be an option, we have to start the session with it on.
			// We change it immediately back to default below before returning the session.
			permissionMode: "bypassPermissions",
			permissionPromptToolName: PERMISSION_TOOL_NAME,
			includePartialMessages: true, // TODO: make this configurable, and handle event filtering accordingly
			hooks: {
				...options?.hooks,
				PreToolUse: [
					...(options?.hooks?.["PreToolUse"] || []),
					{
						hooks: [preToolUseHook],
					},
				],
				PostToolUse: [
					...(options?.hooks?.["PostToolUse"] || []),
					{
						hooks: [postToolUseHook],
					},
				],
			},
			// executable: options?.executable,
		}

		const allowedTools: string[] = []
		const disallowedTools: string[] = []
		if (this.clientCapabilities?.fs?.readTextFile) {
			allowedTools.push(toolNames.read)
			disallowedTools.push("Read")
		}
		if (this.clientCapabilities?.fs?.writeTextFile) {
			disallowedTools.push("Write", "Edit")
		}
		if (this.clientCapabilities?.terminal) {
			allowedTools.push(toolNames.bashOutput, toolNames.killShell)
			disallowedTools.push("Bash", "BashOutput", "KillShell")
		}

		if (allowedTools.length > 0) {
			newOptions.allowedTools = allowedTools
		}
		if (disallowedTools.length > 0) {
			newOptions.disallowedTools = disallowedTools
		}

		// Start the query, ensuring we cancel it when needed.
		const abortController = options?.abortController
		if (abortController?.signal.aborted) {
			throw new Error("Cancelled")
		}
		const q = query({
			prompt: input,
			options: newOptions,
		})
		abortController?.signal.addEventListener("abort", async () => {
			try {
				logInfo("Aborting query")
				await q.interrupt()
				logInfo("Aborted query")
			} catch (error) {
				logError("Error aborting query", error)
			}
		})

		const models = await getAvailableModels(q)
		const permissionMode = "default"
		// Change it back to default
		await q.setPermissionMode(permissionMode)
		this.sessions[sessionId] = {
			query: q,
			input: input,
			cancelled: false,
			permissionMode,
		}

		void getAvailableSlashCommands(q).then((availableCommands) => {
			setTimeout(() => {
				void this.client.sessionUpdate({
					sessionId,
					update: {
						sessionUpdate: "available_commands_update",
						availableCommands,
					},
				})
			}, 0)
		})

		return {
			sessionId,
			models,
			modes: {
				currentModeId: permissionMode,
				availableModes: [
					{
						id: "default",
						name: "Always Ask",
						description: "Prompts for permission on first use of each tool",
					},
					{
						id: "acceptEdits",
						name: "Accept Edits",
						description: "Automatically accepts file edit permissions for the session",
					},
					{
						id: "bypassPermissions",
						name: "Bypass Permissions",
						description: "Skips all permission prompts",
					},
					{
						id: "plan",
						name: "Plan Mode",
						description: "Claude can analyze but not modify files or execute commands",
					},
				],
			},
		}
	}

	async authenticate(_params: AuthenticateRequest): Promise<void> {
		throw new Error("Method not implemented.")
	}

	async prompt(params: PromptRequest): Promise<PromptResponse> {
		if (!this.sessions[params.sessionId]) {
			throw new Error("Session not found")
		}

		this.sessions[params.sessionId].cancelled = false

		const { query, input } = this.sessions[params.sessionId]

		input.push(promptToClaude(params))
		while (true) {
			const { value: message, done } = await query.next()
			if (done || !message) {
				if (this.sessions[params.sessionId].cancelled) {
					return { stopReason: "cancelled" }
				}
				break
			}
			switch (message.type) {
				case "system":
					switch (message.subtype) {
						case "init":
							this.sessions[params.sessionId].claudeCodeSessionId = message.session_id
							break
						case "compact_boundary":
							break
						case "hook_response":
							break
						default:
							// @ts-expect-error this is expected to be unreachable
							this.logger.error(`unhandled system message subtype ${message.subtype}`)
							break
					}
					break
				case "result": {
					if (this.sessions[params.sessionId].cancelled) {
						return { stopReason: "cancelled" }
					}

					// todo!() how is rate-limiting handled?
					switch (message.subtype) {
						case "success": {
							if (message.result.includes("Please run /login")) {
								throw RequestError.authRequired()
							}
							return { stopReason: "end_turn" }
						}
						case "error_during_execution":
							return { stopReason: "refusal" }
						case "error_max_turns":
							return { stopReason: "max_turn_requests" }
						default:
							return { stopReason: "refusal" }
					}
				}
				case "user":
				case "assistant": {
					if (this.sessions[params.sessionId].cancelled) {
						break
					}

					// Slash commands like /compact can generate invalid output... doesn't match
					// their own docs: https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-slash-commands#%2Fcompact-compact-conversation-history
					if (
						typeof message.message.content === "string" &&
						message.message.content.includes("<local-command-stdout>")
					) {
						this.logger.log("assistant message", message.message.content)
						break
					}

					if (
						typeof message.message.content === "string" &&
						message.message.content.includes("<local-command-stderr>")
					) {
						this.logger.error("assistant error", message.message.content)
						break
					}
					// Skip these user messages for now, since they seem to just be messages we don't want in the feed
					if (message.type === "user" && typeof message.message.content === "string") {
						break
					}

					if (
						message.type === "assistant" &&
						message.message.model === "<synthetic>" &&
						Array.isArray(message.message.content) &&
						message.message.content.length === 1 &&
						message.message.content[0].type === "text" &&
						message.message.content[0].text.includes("Please run /login")
					) {
						throw RequestError.authRequired()
					}

					await sendAcpNotifications(
						message,
						params.sessionId,
						this.sessions[params.sessionId],
						this.toolUseCache,
						this.fileContentCache,
						this.client,
						this.logger,
					)
					break
				}
				case "stream_event": {
					if (this.sessions[params.sessionId].cancelled) {
						break
					}

					await sendAcpNotifications(
						message,
						params.sessionId,
						this.sessions[params.sessionId],
						this.toolUseCache,
						this.fileContentCache,
						this.client,
						this.logger,
					)
					break
				}

				default:
					// @ts-expect-error this is expected to be unreachable
					this.logger.error(`unhandled message type ${message.type}`)
					break
			}
		}
		throw new Error("Session did not end in result")
	}

	async cancel(params: CancelNotification): Promise<void> {
		if (!this.sessions[params.sessionId]) {
			throw new Error("Session not found")
		}
		this.sessions[params.sessionId].cancelled = true
		await this.sessions[params.sessionId].query.interrupt()
	}

	async setSessionModel(params: SetSessionModelRequest): Promise<SetSessionModelResponse | void> {
		if (!this.sessions[params.sessionId]) {
			throw new Error("Session not found")
		}
		await this.sessions[params.sessionId].query.setModel(params.modelId)
	}

	async setSessionMode(params: SetSessionModeRequest): Promise<SetSessionModeResponse> {
		if (!this.sessions[params.sessionId]) {
			throw new Error("Session not found")
		}

		switch (params.modeId) {
			case "default":
			case "acceptEdits":
			case "bypassPermissions":
			case "plan":
				this.sessions[params.sessionId].permissionMode = params.modeId
				try {
					await this.sessions[params.sessionId].query.setPermissionMode(params.modeId)
				} catch (error) {
					const errorMessage = error instanceof Error && error.message ? error.message : "Invalid Mode"

					throw new Error(errorMessage)
				}
				return {}
			default:
				throw new Error("Invalid Mode")
		}
	}

	async readTextFile(params: ReadTextFileRequest): Promise<ReadTextFileResponse> {
		const response = await this.client.readTextFile(params)
		if (!params.limit && !params.line) {
			this.fileContentCache[params.path] = response.content
		}
		return response
	}

	async writeTextFile(params: WriteTextFileRequest): Promise<WriteTextFileResponse> {
		const response = await this.client.writeTextFile(params)
		this.fileContentCache[params.path] = params.content
		return response
	}
}

async function getAvailableModels(query: Query): Promise<SessionModelState> {
	const models = await query.supportedModels()

	// Query doesn't give us access to the currently selected model, so we default to "default" if it is there,
	// otherwise we just choose the first model in the list.
	const currentModel = models.find((model) => model.value === DEFAULT_MODEL_ID) || models[0]
	await query.setModel(currentModel.value)

	const availableModels = models.map((model) => ({
		modelId: model.value,
		name: model.displayName,
		description: model.description,
	}))

	return {
		availableModels,
		currentModelId: currentModel.value,
	}
}

async function getAvailableSlashCommands(query: Query): Promise<AvailableCommand[]> {
	const UNSUPPORTED_COMMANDS = [
		"add-dir",
		"agents", // Modal
		"bashes", // Modal
		"bug", // Modal
		"clear", // Escape Codes
		"config", // Modal
		"context", // Escape Codes
		"cost", // Escape Codes
		"doctor", // Escape Codes
		"exit",
		"export", // Modal
		"help", // Modal
		"hooks", // Modal
		"ide", // Modal
		"install-github-app", // Modal
		"login",
		"logout",
		"memory",
		"mcp",
		"migrate-installer", // Modal
		"model", // Not supported via SDK?
		"output-style", // Modal
		"output-style:new", // Modal
		"permissions", // Modal
		"privacy-settings",
		"release-notes", // Escape Codes
		"resume",
		"status", // Not supported via SDK?
		"statusline", // Not needed
		"terminal-setup", // Not needed
		"todos", // Escape Codes
		"vim", // Not needed
	]
	const commands = await query.supportedCommands()

	return commands
		.map((command) => {
			const input = command.argumentHint ? { hint: command.argumentHint } : null
			return {
				name: command.name,
				description: command.description || "",
				input,
			}
		})
		.filter(
			(command: AvailableCommand) =>
				!(command.name.match(/\(MCP\)/) || UNSUPPORTED_COMMANDS.includes(command.name)),
		)
}

function formatUriAsLink(uri: string): string {
	try {
		if (uri.startsWith("file://")) {
			const path = uri.slice("file://".length) // Remove "file://"
			const name = path.split("/").pop() || path
			return `[@${name}](${uri})`
		} else if (uri.startsWith("zed://")) {
			const parts = uri.split("/")
			const name = parts[parts.length - 1] || uri
			return `[@${name}](${uri})`
		}
		return uri
	} catch {
		return uri
	}
}

function promptToClaude(prompt: PromptRequest): SDKUserMessage {
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const content: any[] = []
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	const context: any[] = []

	for (const chunk of prompt.prompt) {
		switch (chunk.type) {
			case "text":
				content.push({ type: "text", text: chunk.text })
				break
			case "resource_link": {
				const formattedUri = formatUriAsLink(chunk.uri)
				content.push({
					type: "text",
					text: formattedUri,
				})
				break
			}
			case "resource": {
				if ("text" in chunk.resource) {
					const formattedUri = formatUriAsLink(chunk.resource.uri)
					content.push({
						type: "text",
						text: formattedUri,
					})
					context.push({
						type: "text",
						text: `\n<context ref="${chunk.resource.uri}">\n${chunk.resource.text}\n</context>`,
					})
				}
				// Ignore blob resources (unsupported)
				break
			}
			case "image":
				if (chunk.data) {
					content.push({
						type: "image",
						source: {
							type: "base64",
							data: chunk.data,
							media_type: chunk.mimeType,
						},
					})
				} else if (chunk.uri && chunk.uri.startsWith("http")) {
					content.push({
						type: "image",
						source: {
							type: "url",
							url: chunk.uri,
						},
					})
				}
				break
			// Ignore audio and other unsupported types
			default:
				break
		}
	}

	content.push(...context)

	return {
		type: "user",
		message: {
			role: "user",
			content: content,
		},
		session_id: prompt.sessionId,
		parent_tool_use_id: null,
	}
}

/**
 * Convert an SDKAssistantMessage (Claude) to a SessionNotification (ACP).
 * Only handles text, image, and thinking chunks for now.
 */
export async function sendAcpNotifications(
	message: SDKAssistantMessage | SDKUserMessage | SDKUserMessageReplay | SDKPartialAssistantMessage,
	sessionId: string,
	sessionInfo: Session,
	toolUseCache: ToolUseCache,
	fileContentCache: { [key: string]: string },
	client: AgentSideConnection,
	logger: ACPLogger,
): Promise<void> {
	const notifications: SessionNotification[] = []
	const _meta = {
		externalSessionId: sessionInfo.claudeCodeSessionId,
	}

	// Handle streamed (partial) events for text and thinking.
	if (message.type === "stream_event") {
		if (message.event.type === "content_block_delta") {
			if (message.event.delta.type === "text_delta") {
				notifications.push({
					_meta,
					sessionId,
					update: {
						sessionUpdate: "agent_message_chunk",
						content: {
							type: "text",
							text: message.event.delta.text,
						},
					},
				})
			} else if (message.event.delta.type === "thinking_delta") {
				notifications.push({
					_meta,
					sessionId,
					update: {
						sessionUpdate: "agent_thought_chunk",
						content: {
							type: "text",
							text: message.event.delta.thinking,
						},
					},
				})
			} else {
				//Other events are skipped. They'll be handled when the full message is received.
			}
		} else {
			//Other events are skipped. They'll be handled when the full message is received.
		}
	} else {
		// Handle other events except for text and thinking.
		const content = message.message.content

		if (typeof content === "string") {
			notifications.push({
				_meta,
				sessionId,
				update: {
					sessionUpdate: message.type === "assistant" ? "agent_message_chunk" : "user_message_chunk",
					content: {
						type: "text",
						text: content,
					},
				},
			})
		}

		const handleToolResult = async (toolUse: CachedToolUse) => {
			const chunk = toolUse.output
			if (!toolUse.toolResponse || !chunk) {
				logger.log(
					`skipping handleToolResult update for ${toolUse.id}. toolResponse: ${!!toolUse.toolResponse} output: ${!!toolUse.output}`,
				)
				// Wait for both output formats to be available before broadcasting the update.
				return
			}

			if (toolUse.name !== "TodoWrite") {
				logger.log("sending handleToolResult update")
				await client.sessionUpdate({
					_meta,
					sessionId,
					update: {
						_meta: {
							toolResponse: toolUse.toolResponse,
							toolName: toolUse.name,
						},
						toolCallId: chunk.tool_use_id,
						sessionUpdate: "tool_call_update",
						status: chunk.is_error ? "failed" : "completed",
						...toolUpdateFromToolResult(chunk, toolUseCache[chunk.tool_use_id]),
					},
				})
			}
		}

		// Only handle the first chunk for streaming; extend as needed for batching
		for (const chunk of content) {
			let update: SessionNotification["update"] | null = null
			if (typeof chunk === "string") {
				// Skipped, as text is handled through streaming.
				continue
			}
			switch (chunk.type) {
				case "text":
					// Skipped, as text is handled through streaming.
					break
				case "image":
					update = {
						sessionUpdate: message.type === "assistant" ? "agent_message_chunk" : "user_message_chunk",
						content: {
							type: "image",
							data: chunk.source.type === "base64" ? chunk.source.data : "",
							mimeType: chunk.source.type === "base64" ? chunk.source.media_type : "",
							uri: chunk.source.type === "url" ? chunk.source.url : undefined,
						},
					}
					break
				case "thinking":
					// Skipped, as thinking is handled through streaming.
					break
				case "tool_use":
					toolUseCache[chunk.id] = chunk
					registerHookCallback(chunk.id, {
						onPostToolUseHook: async (toolUseId, toolInput, toolResponse) => {
							logger.log(
								`Got a tool result from a hook for tool use #${toolUseId}: ${JSON.stringify(toolResponse)}`,
							)
							const toolUse = toolUseCache[toolUseId]
							if (toolUse) {
								toolUse.toolResponse = toolResponse
								await handleToolResult(toolUse)
							} else {
								logger.error(
									`[claude-code-acp] Got a tool result from a hook for tool use that wasn't tracked: ${toolUseId}`,
								)
							}
						},
					})
					if (chunk.name === "TodoWrite") {
						update = {
							sessionUpdate: "plan",
							entries: planEntries(chunk.input as { todos: ClaudePlanEntry[] }),
						}
					} else {
						let rawInput
						try {
							rawInput = JSON.parse(JSON.stringify(chunk.input))
						} catch {
							// ignore if we can't turn it to JSON
						}
						const toolUseInfo = toolInfoFromToolUse(chunk, fileContentCache)
						update = {
							toolCallId: chunk.id,
							sessionUpdate: "tool_call",
							rawInput,
							status: "pending",
							_meta: {
								toolName: toolUseInfo.toolName,
							},
							...toolUseInfo,
						}
					}
					break

				case "tool_result": {
					const toolUse = toolUseCache[chunk.tool_use_id]
					if (!toolUse) {
						logger.error(
							`[claude-code-acp] Got a tool result for tool use that wasn't tracked: ${chunk.tool_use_id}`,
						)
						break
					}
					toolUse.output = chunk
					await handleToolResult(toolUse)
					break
				}

				default:
					throw new Error("unhandled chunk type: " + chunk.type)
			}
			if (update) {
				notifications.push({
					_meta,
					sessionId,
					update,
				})
			}
		}
	}

	for (const notification of notifications) {
		await client.sessionUpdate(notification)
	}
	return
}

export function runAcp() {
	const input = nodeToWebWritable(process.stdout)
	const output = nodeToWebReadable(process.stdin)

	// @ts-expect-error not sure what's going on
	const stream = ndJsonStream(input, output)
	new AgentSideConnection((client) => new ClaudeAcpAgent(client), stream)
}
