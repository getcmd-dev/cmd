import { logInfo } from "@/logger"
import { LocalExecutable, Message, Tool } from "@/server/schemas/sendMessageSchema"
import { Response } from "express"
import { respondUsingResponseStream, ResponseChunkWithoutIndex } from "../sendMessage"
import { AsyncStream } from "@/utils/asyncStream"
import { askAppForPermission, toACPContentBlocks, toMessageStream } from "../acp/clients/ACPClient"
import { GeminiCLIACPClient } from "../acp/clients/geminiCLI/geminiCLIACPClient"
import { SendMessageToExternalAgent } from "."
import { extractExecutableInfo } from "./clients/helper"

// TODO: support resuming the conversation after the app restarts.
// This is not supported by the Gemini CLI yet, nor by ACP.
// The current setup spawns one shared subprocess to Gemini CLI for all sessions, and uses Gemini CLI's ACP support to manage concurrent sessions. Within this setup it's impossible to resume sessions.
// An alternative would be to spawn a new subprocess for each session, using the `--resume` parameter and writting our own ACP client using Gemini CLI's API.
// However, Gemini CLI doesn't have an equivalent to @anthropic-ai/claude-agent-sdk which is an SDK independent of the main library. Without this, we would force the user to use the version of Gemini CLI embedded in cmd, instead of their own (and incure an app size cost for this embedding).
// We could manage all the configuration, and use `--output-format stream-json` to stream updates to an internal ACP client, but this is a lot of work. Instead we are not supporting resuming sessions for now, and will wait on ACP making progress on this.

const acpClients: Record<string, GeminiCLIACPClient> = {}

export const sendMessageToGeminiCLI: SendMessageToExternalAgent = async (
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
		tools: _tools,
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

	// get the id of the Gemini CLI session to resume
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

	const pathToExecutable = process.env.GEMINI_CLI_PROXY || executableInfo.path

	const messageContent = toACPContentBlocks(newUserMessages)
	if (existingSessionId && !acpClients[threadId]) {
		logInfo(
			`Gemini CLI doesn't support resuming the conversation after the app restarts. Continuing without resuming.`,
		)
	}
	const acpClient =
		acpClients[threadId] ||
		new GeminiCLIACPClient({
			args: executableInfo.args,
			path: pathToExecutable,
		})
	acpClients[threadId] = acpClient
	const { sessionId, events } = await acpClient.prompt(
		{ cwd: localExecutable.cwd },
		messageContent,
		threadId,
		async ({ toolCall, toolName }) => {
			return await askAppForPermission({ toolCall, toolName, eventStream })
		},
	)
	eventStream.yield({ type: "internal_content", value: { type: "session_id", sessionId } })
	abortController.signal.addEventListener("abort", async () => {
		await acpClient?.cancel(sessionId)
	})

	eventStream.pipeFrom(toMessageStream(events))

	return eventStream
}
