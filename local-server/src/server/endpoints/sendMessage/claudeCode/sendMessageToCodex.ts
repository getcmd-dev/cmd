import { logError, logInfo } from "@/logger"
import { LocalExecutable, Message, Tool } from "@/server/schemas/sendMessageSchema"
import { Codex } from "@openai/codex-sdk"
import { Response } from "express"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "../sendMessage"
import { AsyncStream } from "@/utils/asyncStream"
import { spawn } from "@/utils/spawn-promise"
import { askAppForPermission, toACPContentBlocks, toMessageStream } from "../acp/clients/ACPClient"
import { ContentBlock } from "@agentclientprotocol/sdk"
import { sendCommandToHostApp } from "../../interProcessesBridge"
import { CodexACPClient } from "../acp/clients/codex/codexACPClient"

// TODO: support resuming the conversation after the app restarts.

let acpClient: CodexACPClient | undefined

export const sendMessageToCodex = async (
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
	logInfo("done responding, terminating request")
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
			logInfo("Response closed (client disconnected), killing Codex process.")
			abortController.abort()
		}
	})
	const eventStream = new AsyncStream<ResponseChunkWithoutIndex>()

	// get the id of the Codex session to resume
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

	const newUserMessages = messages.slice(firstNewUserMessagesIdx)

	const executableInfo = await extractExecutableInfo(localExecutable)

	if (responseIsTerminated) {
		// The response has already been cancelled, abort.
		eventStream.done()
		return eventStream
	}

	const messageContent = toACPContentBlocks(newUserMessages)

	// Provide a name for the conversation, if needed.
	// TODO: expose the models in cmd directly to the API, so that the conversation naming
	// can be done like for any AI provider with a lower tier model.
	if (!existingSessionId) {
		nameConversation(messageContent, executableInfo.path)
			.then((name) => {
				sendCommandToHostApp({
					type: "execute-command",
					command: "set_conversation_name",
					input: {
						name,
						threadId,
					},
				})
			})
			.catch((error) => {
				logError("Failed to name conversation with Codex", error)
			})
	}

	acpClient = acpClient || new CodexACPClient()
	const { sessionId, events } = await acpClient.prompt(
		{ cwd: localExecutable.cwd },
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

/* Name the conversation based on the first message. */
const nameConversation = async (messages: ContentBlock[], executablePath): Promise<string> => {
	const codex = new Codex({
		codexPathOverride: executablePath,
	})
	const thread = codex.startThread()
	const mergedMessage = messages
		.filter((message) => message.type === "text")
		.map((message) => message.text)
		.join("\n")
	const result =
		await thread.run(`You are an expert in naming conversations. Below is the first message of a conversation and you need to provide a concise and descriptive name for the conversation, under 50 characters.

		YOU MUST RESPOND WITH ONLY THE NAME OF THE CONVERSATION, NOTHING ELSE.

		good output example : \`Fixing the login flow in the app\`
		bad output example: \`Here's a concise summary of the conversation: Fixing the login flow in the app\`
		bad output example: \`I'm happy to assist you with that. Here's a concise summary of the conversation: Fixing the login flow in the app\`)

		Conversation to give a name to:
		${mergedMessage}
`)

	return result.finalResponse || "New conversation"
}
