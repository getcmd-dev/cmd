import { logError, logInfo } from "@/logger"
import { LocalExecutable, Message, Tool } from "@/server/schemas/sendMessageSchema"
import { Response } from "express"
import { Options } from "@anthropic-ai/claude-agent-sdk"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "../sendMessage"
import { AsyncStream } from "@/utils/asyncStream"
import { spawn } from "@/utils/spawn-promise"
import { ClaudeCodeACPClient } from "../acp/clients/claudeCode/claudeCodeACPClient"
import { askAppForPermission, toACPContentBlocks, toMessageStream } from "../acp/clients/ACPClient"

// Constants
const TOOL_NAME_PREFIX = "claude_code_"

let acpClient: ClaudeCodeACPClient | undefined

export const sendMessageToClaudeCode = async (
	{
		messages,
		threadId,
		localExecutable,
		tools,
	}: {
		messages: Message[]
		threadId: string
		localExecutable: LocalExecutable
		tools: Tool[]
	},
	res: Response,
) => {
	const eventStream = await createEventStream(res, {
		messages,
		localExecutable,
		threadId,
		tools,
	})
	await respondUsingResponseStream(eventStream, res)
	logInfo("done responsing, terminating request")
	res.end()
}

const createEventStream = async (
	res: Response,
	{
		messages,
		localExecutable,
		threadId,
		tools,
	}: {
		messages: Message[]
		localExecutable: LocalExecutable
		threadId: string
		tools: Tool[]
	},
): Promise<AsyncStream<ResponseChunkWithoutIndex>> => {
	// Setup response event listeners first
	let responseCompletedByServer = false
	let responseIsTerminated = false
	res.on("finish", () => {
		logInfo("response finished")
		responseCompletedByServer = true
		responseIsTerminated = true
		// We still call abort here, as the server-side termination could come from an error
		// in the event stream, in which case we need to stop the agent.
		abortController.abort()
	})
	const abortController = new AbortController()
	res.on("close", () => {
		logInfo("response close")
		responseIsTerminated = true

		if (!responseCompletedByServer) {
			logInfo("Response closed (client disconnected), killing Claude Code process.")
			abortController.abort()
		}
	})
	const eventStream = new AsyncStream<ResponseChunkWithoutIndex>()

	// get the id of the Claude Code session to resume
	const existingSessionId = ((): string | undefined => {
		for (const message of messages) {
			if (message.role === "assistant") {
				for (const content of message.content) {
					if (content.type === "internal_content" && content.value.type === "session_id") {
						return content.value.sessionId as string
					}
				}
			}
		}
		return undefined
	})()
	// get the user messages since the last message sent
	let firstNewUserMessagesIdx = messages.length
	while (firstNewUserMessagesIdx > 0 && messages[firstNewUserMessagesIdx - 1].role === "user") {
		firstNewUserMessagesIdx--
	}

	// Merge all the user messages into a single message with several content parts
	// as since 2.0 Claude Code responds to each received message before processing the next ones.
	const newUserMessages = messages.slice(firstNewUserMessagesIdx)

	const executableInfo = await extractExecutableInfo(localExecutable)

	// Try to remove env variable that might lead to CC exiting with status 1
	// See https://github.com/anthropics/claude-code/issues/4619#issuecomment-3217014571
	const env = { ...localExecutable.env }
	delete env.NODE_OPTIONS
	delete env.VSCODE_INSPECTOR_OPTIONS

	// TODO: update names here once Claude Code tools have been removed from the app.
	// The user might decide that some tools are not available.
	// We only compare the list of available tools to the list of tools supported by the app.
	// Other tools supported by Claude Code cannot be enabled/disabled by the app and remain available by default.
	const availableTools = tools.filter((tool) => tool.name.startsWith(TOOL_NAME_PREFIX)).map((tool) => tool.name)
	const disallowedTools = [
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
	].filter((toolName) => !availableTools.includes(`${TOOL_NAME_PREFIX}${toolName}`))
	if (disallowedTools.length) {
		logInfo(`disallowedTools: ${disallowedTools}`)
	}

	const pathToClaudeCodeExecutable = process.env.CLAUDE_CODE_PROXY || executableInfo.path

	let onError: ((error: string) => void) | undefined
	const receivedError = new Promise<string>((resolve) => {
		onError = resolve
	})
	const options: Options & { cwd: string } = {
		pathToClaudeCodeExecutable,
		executableArgs: executableInfo.args,
		cwd: localExecutable.cwd,
		// Note: if disallowedTools changed mid session, the new parameter is ignored.
		disallowedTools,
		env,
		abortController,
		resume: existingSessionId,
		stderr: (data: string) => {
			if (data.startsWith("Spawning Claude Code native binary")) {
				return
			}
			if (data.trim().length && data.trim() !== "Error") {
				onError?.(data)
				onError = undefined
				// TODO: clarify what's going on
				logError(`Claude Code stderr: ${data}`)
				eventStream.yield({ type: "error", message: data })
				eventStream.done()
				abortController.abort()
			}
		},
	}

	if (responseIsTerminated) {
		// The response has already been cancelled, abort.
		eventStream.done()
		return eventStream
	}

	const messageContent = toACPContentBlocks(newUserMessages)

	const sendMessage = async () => {
		acpClient = acpClient || new ClaudeCodeACPClient()
		const { events, sessionId } = await acpClient.prompt(
			options,
			messageContent,
			threadId,
			async ({ toolCall, toolName }) => {
				return await askAppForPermission({ toolCall, toolName, eventStream })
			},
		)
		abortController.signal.addEventListener("abort", async () => {
			await acpClient?.cancel(sessionId)
		})

		eventStream.pipeFrom(toMessageStream(events))

		return eventStream
	}

	// Handle cases where an error occurs during initialization,
	// which might prevent the ACP client from ever responding.
	return await Promise.race([
		sendMessage(),
		receivedError.then((error) => {
			throw new Error(error)
		}),
	])
}

// Extract the executable path and args from the LocalExecutable configuration.
// `localExecutable.executable` is a string that may contain the executable name or path along with arguments.
// For instance `claude --dangerously-skip-permissions`
const extractExecutableInfo = async (localExecutable: LocalExecutable): Promise<{ path: string; args: string[] }> => {
	const parts = localExecutable.executable.match(/(?:[^\s"]+|"[^"]*")+/g) || []
	const execName = parts[0]?.replace(/(^"|"$)/g, "") // Remove surrounding quotes if any
	const args = parts.slice(1).map((arg) => arg.replace(/(^"|"$)/g, ""))
	if (!execName) {
		throw new Error("Invalid executable path")
	}
	if (execName.startsWith("/")) {
		// absolute path
		return { path: execName, args }
	}
	const execPath = await spawn("which", {
		args: [execName],
		env: localExecutable.env,
		cwd: localExecutable.cwd,
	}).then((r) => r.stdout.trim())
	if (!execPath.length) {
		throw new Error(`Executable ${execName} not found in PATH`)
	}
	return { path: execPath, args }
}
