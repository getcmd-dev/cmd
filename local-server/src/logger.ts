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

/** Detect if the parameter is an error, otherwise create a new error with the parameter as the message */
const convertToError = (error: unknown): Error => {
	if (isUserFacingError(error)) {
		return error
	}
	if (error instanceof Error) {
		return error
	}
	if (typeof error === "object" && error !== null) {
		try {
			return new Error(JSON.stringify(error))
		} catch {
			return new Error(`${error}`)
		}
	}
	return new Error(`${error}`)
}

/** Log the error, and record it appropriately */
function logError(message: string, error: unknown): void
function logError(error: unknown): void
function logError(errorOrMessage: unknown, error?: unknown): void {
	let err: Error
	let message: string
	if (error !== undefined) {
		err = convertToError(error)
		message = errorOrMessage as string
	} else {
		err = convertToError(errorOrMessage)
		message = ""
	}
	if (process.env.NODE_ENV === "production") {
		if (isUserFacingError(error)) {
			captureException(error, { data: error.underlyingError?.message })
		} else {
			captureException(error)
		}
	}
	writeToLog("ERROR", `${message}\n${err.message}\n${err.stack}`)
	if (process.env.LOG_TO_CONSOLE) {
		console.error(err, err.stack)
	}
}

const logInfo = (info: string | object) => {
	if (typeof info !== "string") {
		info = JSON.stringify(info, null, 2)
	}
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
