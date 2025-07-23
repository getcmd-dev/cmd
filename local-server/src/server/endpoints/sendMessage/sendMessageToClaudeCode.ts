import { logError, logInfo } from "@/logger"
import { LocalExecutable, Message } from "@/server/schemas/sendMessageSchema"
import { CoreMessage, CoreUserMessage } from "ai"
import { Response } from "express"
import { spawn } from "child_process"
// import {
// 	MessageParam as AnthropicSDKMessageParam,
// 	Message as AnthropicSDKMessage,
// } from "@anthropic-ai/sdk/resources/messages"
import { type SDKMessage } from "@anthropic-ai/claude-code"

export const sendMessageToClaudeCode = async (
	messages: CoreMessage[],
	localExecutable: LocalExecutable,
	res: Response,
) => {
	return new Promise<void>((resolve, reject) => {
		let firstNewUserMessagesIdx = messages.length
		while (firstNewUserMessagesIdx > 0 && messages[firstNewUserMessagesIdx - 1].role === "user") {
			firstNewUserMessagesIdx--
		}
		logInfo(`First new user messages index: ${firstNewUserMessagesIdx} / Total messages: ${messages.length}`)

		const newUserMessages = messages.slice(firstNewUserMessagesIdx).filter(isCoreUserMessage)
		const newUserMessagesText = newUserMessages
			.map((message) => {
				if (typeof message.content === "string") {
					return message.content
				}
				return message.content
					.map((content) => {
						if (content.type === "text") {
							return content.text
						}
						return undefined
					})
					.filter(Boolean)
					.join("\n")
			})
			.join("\n")

		logInfo(`Spawning Claude with executable: ${localExecutable.executable}`)
		logInfo(`New user messages text: "${newUserMessagesText}"`)

		// Use stdin instead of -p flag to avoid hanging
		const args = ["--output-format", "stream-json", "--verbose"]
		logInfo(`Full command: ${localExecutable.executable} ${args.join(" ")} (with stdin)`)

		const child = spawn(localExecutable.executable, args, {
			stdio: ["pipe", "pipe", "pipe"],
			env: localExecutable.env,
			cwd: localExecutable.cwd,
		})
		logInfo(`Process spawned with PID: ${child.pid}`)

		// Write to stdin instead of using -p flag
		child.stdin.write(newUserMessagesText)
		child.stdin.end()

		child.on("error", (err) => {
			logError(`Failed to spawn Claude process: ${err.message}`)
			reject(err)
		})

		child.on("spawn", () => {
			logInfo(`Claude process successfully spawned`)
		})

		// Add a timeout to prevent hanging indefinitely
		const timeout = setTimeout(() => {
			logError(`Claude process timed out after 30 seconds, killing process`)
			child.kill("SIGTERM")
			reject(new Error("Claude process timed out"))
		}, 30000)

		let hasReceivedOutput = false

		child.stdout.setEncoding("utf8")
		child.stderr.setEncoding("utf8")

		child.stdout.on("data", (data) => {
			hasReceivedOutput = true
			const output = data.toString()
			const payload = JSON.parse(output) as SDKMessage
			logInfo(`Received output from Claude: ${output}`)
			// Send the output to the response if available
			if (res && !res.headersSent) {
				res.write(output)
			}
		})

		child.stderr.on("data", (data) => {
			const error = data.toString()
			logError(`Received error from Claude: ${error}`)
		})

		child.on("close", (code) => {
			clearTimeout(timeout)
			logInfo(`Claude process exited with code ${code}`)
			if (res && !res.headersSent) {
				res.end()
			}
			if (hasReceivedOutput || code === 0) {
				resolve()
			} else {
				reject(new Error(`Claude process exited with code ${code} and no output`))
			}
		})

		child.on("exit", (code, signal) => {
			clearTimeout(timeout)
			logInfo(`Claude process exit event: code=${code}, signal=${signal}`)
		})
	})
}

export const isCoreUserMessage = (message: CoreMessage): message is CoreUserMessage => {
	return message.role === "user"
}
