import "./utils/instrument"
import { appendFileSync, mkdirSync, writeFileSync } from "fs"
import { join } from "path"
import { captureException } from "@sentry/node"
import { isUserFacingError } from "./server/errors"
// Define log levels
type LogLevel = "ERROR" | "INFO"

const isRunningTest = process.env.NODE_ENV === "test"

// Get the directory where this file is located
const LOG_FILE = join(
	__dirname,
	"logs",
	`${new Date().toISOString().replace("T", "__").replace(/:/g, "-").replace(/Z$/, "")}.node-server.txt`,
)
const SHARED_LOG_FILE = join(__dirname, "logs", `all-sessions.txt`)
if (isRunningTest) {
	// don't log to file in tests
} else {
	try {
		mkdirSync(join(__dirname, "logs"), { recursive: true })
	} catch (err) {
		console.error("Failed to create logs directory:", err)
	}
}

export const startNewLogSession = ({ lineSpacing }: { lineSpacing: number } = { lineSpacing: 5 }) => {
	const spacing = "\n".repeat(lineSpacing)
	appendFileSync(LOG_FILE, spacing)
	appendFileSync(SHARED_LOG_FILE, spacing)
}

const writeToLog = (level: LogLevel, message: unknown) => {
	const timestamp = new Date().toISOString()
	const logMessage = `[${timestamp}] [${level}] ${message instanceof Error ? message.stack || message.message : (message as string)}\n`
	if (isRunningTest) {
		return
	}

	// Write to file
	try {
		appendFileSync(LOG_FILE, logMessage)
		appendFileSync(SHARED_LOG_FILE, logMessage)
	} catch (err) {
		console.error("Failed to write to log file:", err)
	}
}

const logError = (error: unknown) => {
	if (error instanceof Error) {
		writeToLog("ERROR", error.stack)
		return
	}
	if (process.env.NODE_ENV === "production") {
		if (isUserFacingError(error)) {
			captureException(error, { data: error.underlyingError?.message })
		} else {
			captureException(error)
		}
	}
	const stackTrace = new Error("").stack
	if (typeof error === "object" && error !== null) {
		try {
			writeToLog("ERROR", JSON.stringify(error))
			writeToLog("ERROR", stackTrace)
		} catch {
			writeToLog("ERROR", error)
			writeToLog("ERROR", stackTrace)
		}
	} else {
		writeToLog("ERROR", error)
		writeToLog("ERROR", stackTrace)
	}
	if (process.env.LOG_TO_CONSOLE) {
		console.error(error, error instanceof Error ? error.stack : undefined)
	}
}

const logInfo = (info: string) => {
	writeToLog("INFO", info)
	if (process.env.LOG_TO_CONSOLE) {
		console.log(info)
	}
}

const saveLogToFile = (fileName: string, log: string): string | undefined => {
	const filePath = join(__dirname, "logs", fileName)
	try {
		mkdirSync(join(__dirname, "logs"), { recursive: true })
		writeFileSync(filePath, log)
		return filePath
	} catch (err) {
		logError(`Failed to save log to file: ${fileName}. Error: ${err}`)
		return undefined
	}
}

export { logError, logInfo, saveLogToFile }
