import "../utils/instrument"
import express from "express"
import Router from "express-promise-router"
import { logInfo } from "../logger"
import { registerEndpoint as registerSendMessageEndpoint } from "./endpoints/sendMessage/sendMessage"
import { registerEndpoint as registerExtensionBridge } from "./endpoints/interProcessesBridge"
import { registerEndpoint as registerListFilesEndpoint } from "./endpoints/tools/listFiles"
import { registerEndpoint as registerSearchFilesEndpoint } from "./endpoints/tools/searchFiles/endpoint"
import { registerEndpoints as registerCheckpointEndpoints } from "./endpoints/checkpoint"
import { registerEndpoint as registerGetFileIconEndpoint } from "./endpoints/getFileIcon"
import errorHandler from "./errorHandler"
import fs from "fs"
import path from "path"
import { setupExpressErrorHandler } from "@sentry/node"
import { AnthropicModelProvider } from "./providers/anthropic"
import { OpenAIModelProvider } from "./providers/openai"
import { startInterProcessesBridge } from "./endpoints/interProcessesBridge"
import { OpenRouterModelProvider } from "./providers/open-router"
import { GroqModelProvider } from "./providers/groq"
import { GeminiModelProvider } from "./providers/gemini"

const connectionInfo: ConnectionInfo = {
	port: 3000, // Default port
}

const app = express()
app.use(express.json({ limit: "1024mb" }))

const router = Router()
app.use(router)

app.get("/", (_, res) => {
	res.send("Hello World!")
})
app.get("/launch", (_, res) => {
	res.json({ ok: true })
})
app.get("/error", () => {
	throw new Error("test error")
})

registerSendMessageEndpoint(
	router,
	[
		new AnthropicModelProvider(),
		new OpenAIModelProvider(),
		new OpenRouterModelProvider(),
		new GroqModelProvider(),
		new GeminiModelProvider(),
	],
	() => {
		return connectionInfo.port
	},
)
registerExtensionBridge(router)
registerListFilesEndpoint(router)
registerSearchFilesEndpoint(router)
registerCheckpointEndpoints(router)
registerGetFileIconEndpoint(router)

if (process.env.NODE_ENV === "production") {
	setupExpressErrorHandler(app)
}

// Add middleware to handle 404 errors (no route matched)
app.use((req, res, next) => {
	const error = new Error(`Not Found - ${req.originalUrl}`) as Error & {
		statusCode: number
	}
	error.statusCode = 404
	next(error)
})

// Keep this last
app.use(errorHandler)

const findAvailablePort = async (startPort: number): Promise<number> => {
	const isPortAvailable = (port: number): Promise<boolean> => {
		return new Promise((resolve) => {
			const server = app
				.listen(port, () => {
					server.close()
					resolve(true)
				})
				.on("error", () => {
					resolve(false)
				})
		})
	}

	let port = startPort
	while (!(await isPortAvailable(port))) {
		port++
	}
	return port
}

export const startServer = async () => {
	const port = await (async () => {
		const portArg = process.argv.findIndex((arg) => arg === "--port")
		if (portArg >= 0 && process.argv[portArg + 1]) {
			// If the port is specified, use it.
			return parseInt(process.argv[portArg + 1], 10)
		} else {
			// Otherwise, find an available port.
			return await findAvailablePort(3000)
		}
	})()

	// Log the port used, so that the client knows which port to connect to.
	connectionInfo.port = port
	console.log(JSON.stringify(connectionInfo))
	fs.writeFileSync(connectionInfoFilePath, JSON.stringify(connectionInfo))

	const server = app.listen(port, () => {
		logInfo(`Server is running on port ${port}`)
	})
	startInterProcessesBridge(server)
}

export type ConnectionInfo = {
	port: number
}

export const connectionInfoFilePath = path.join(__dirname, "last-connection-info.json")
