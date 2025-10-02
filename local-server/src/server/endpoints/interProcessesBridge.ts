/**
 * Manages inter-process communication between the host app and extensions
 * via WebSockets and HTTP endpoints.
 */

import { Request, Response, Router } from "express"
import { logError, logInfo } from "../../logger"
import { WebSocketServer, WebSocket } from "ws"
import * as http from "http"
import { v4 as uuidv4 } from "uuid"

/** Send a message / command to the host application */
export const sendCommandToHostApp = (
	command: ExecuteCommandRequest & { id?: string },
	id: string | undefined = undefined,
): string => {
	const idToUse = id || command.id || uuidv4()
	if (connectionToHostApp === undefined) {
		logError(`No connection to host app. Failed to send command: ${JSON.stringify(command)}`)
		return idToUse
	}
	connectionToHostApp.send(JSON.stringify({ ...command, id: idToUse }))
	return idToUse
}

/** Active WebSocket connection to the host application */
let connectionToHostApp: WebSocket | undefined = undefined
/** Map of pending command IDs to their response handlers */
const pendingCommands: Record<string, (response: unknown, error: Error | undefined) => void> = {}

// Add a helper function for logging with request ID
const logWithId = (id: string | undefined, level: "info" | "error", message: string) => {
	if (message.length > 200) {
		message = message.substring(0, 200) + "..."
	}
	const idPrefix = id ? `[ID:${id}] ` : ""
	if (level === "info") {
		logInfo(`${idPrefix}${message}`)
	} else {
		logError(`${idPrefix}${message}`)
	}
}

/**
 * Initializes the WebSocket server for inter-process communication
 * @param server - HTTP server instance to attach the WebSocket server to
 */
export const startInterProcessesBridge = (server: http.Server) => {
	try {
		const wss = new WebSocketServer({ server })

		wss.on("connection", (ws) => {
			logInfo("Client connected to WS")

			// Close any existing connection
			if (connectionToHostApp && connectionToHostApp.readyState === WebSocket.OPEN) {
				logInfo("Closing existing connection to host app")
				connectionToHostApp.close()
			}

			connectionToHostApp = ws
			ws.on("message", (message) => {
				// Handle different types of WebSocket message data
				let messageString: string
				let messageId: string | undefined

				try {
					if (message instanceof Buffer) {
						messageString = message.toString("utf-8")
					} else if (message instanceof ArrayBuffer) {
						const buffer = Buffer.from(message)
						messageString = buffer.toString("utf-8")
					} else if (typeof message === "string") {
						messageString = message
					} else {
						throw new Error(`Unsupported message type: ${typeof message}`)
					}

					const parsedMessage = JSON.parse(messageString) as ExecuteCommandResponse

					// Extract ID for logging
					messageId = parsedMessage.id

					logWithId(
						messageId,
						"info",
						`Received from WS: ${messageString.substring(0, 200)}${messageString.length > 200 ? "..." : ""}`,
					)

					// Validate message structure
					if (!messageId) {
						throw new Error("Message missing required 'id' field")
					}

					// Handle command response
					if (pendingCommands[messageId]) {
						const handler = pendingCommands[messageId]
						if (parsedMessage.error) {
							handler(undefined, new Error(parsedMessage.error))
						} else {
							handler(parsedMessage.data, undefined)
						}
					} else {
						throw new Error(`No pending command for id '${messageId}'`)
					}
				} catch (error: unknown) {
					const errorMessage = error instanceof Error ? error.message : "Unknown error"
					logWithId(messageId, "error", `Failed to process WebSocket message: ${errorMessage}`)

					ws.send(
						JSON.stringify({
							type: "error",
							error: errorMessage,
							id: messageId || "unknown", // Include ID in error response when available
						}),
					)
				}
			})

			ws.on("close", () => {
				logInfo("Client disconnected from WS")
				connectionToHostApp = undefined
			})

			ws.on("error", (error) => {
				logError(`WebSocket error:`, error)
			})
		})
	} catch (error) {
		logError(`Error starting extension bridge`, error as Error)
	}
}

/**
 * Registers an endpoint for executing commands on the host application
 * @param router - Express router to register the endpoint on
 */
export const registerEndpoint = (router: Router) => {
	router.post("/execute-command", async (req: Request, res: Response) => {
		if (!req.body) {
			res.status(400).send("No body")
			return
		}
		try {
			const body = req.body as ExecuteCommandRequest
			const id: string = uuidv4()

			logWithId(
				id,
				"info",
				`Received command. Has connection to host app: ${!!connectionToHostApp}. Body: ${JSON.stringify(body)}`,
			)

			// Validate the request
			if (!body.command) {
				res.status(400).json("Missing parameter 'command' in request body")
				return
			}
			if (!body.input) {
				res.status(400).json("Missing parameter 'input' in request body")
				return
			}
			if (!connectionToHostApp) {
				res.status(404).json("No connection to host app")
				return
			}

			const commandWithId = {
				...body,
				id,
			}

			const response = await new Promise((resolve, reject) => {
				pendingCommands[id] = (response, error) => {
					delete pendingCommands[id]
					if (error) {
						reject(error)
					} else {
						resolve(response)
					}
				}

				sendCommandToHostApp(commandWithId)
				logWithId(id, "info", `Sent command '${commandWithId.command}' to host app.`)
			})

			logWithId(id, "info", `Received response from host app: ${JSON.stringify(response)}`)

			res.json(response)
		} catch (error) {
			logError(error)
			res.status(500).json(error instanceof Error ? error.message : "Internal server error")
		}
	})
}

/**
 * Request to execute a command on the host application
 */
export type ExecuteCommandRequest = {
	/** Request type identifier */
	type: "execute-command"
	/** Command to execute */
	command: string
	/** Optional input parameters for the command */
	input: Record<string, unknown> | undefined
}

/**
 * Response from the host application after executing a command
 */
export type ExecuteCommandResponse = {
	/** Response type identifier */
	type: "command-response"
	/** Response data if command was successful */
	data: Record<string, unknown> | undefined
	/** Error message if command failed */
	error: string | undefined
	/** Unique ID matching the original request */
	id: string
}
