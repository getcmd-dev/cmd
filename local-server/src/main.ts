import { startNewLogSession, logError, logInfo } from "./logger"
import { startServer } from "./server/server"
import { spawn } from "child_process"

process.on("unhandledRejection", (reason, promise) => {
	// Log the error and prevent crash
	logError(`Unhandled Rejection at: ${promise}, reason: ${reason}`)
})
process.on("uncaughtException", (err) => {
	logError("Caught exception: " + err)
})

startNewLogSession()

// If we should attach to a process, we need to monitor it and exit when it dies.
const attachToIdx = process.argv.findIndex((arg) => arg.startsWith("--attachTo"))
if (attachToIdx !== -1 && attachToIdx + 1 < process.argv.length) {
	const attachToPid = process.argv[attachToIdx + 1]

	logInfo(`Attaching to parent process ${attachToPid}`)

	// Monitor the target process and exit when it dies
	setInterval(() => {
		const child = spawn("kill", ["-0", attachToPid])
		child.on("error", (err) => {
			// System-level errors (like if 'kill' command doesn't exist)
			logError(err)
			process.exit(1)
		})
		child.on("exit", (code) => {
			if (code === 0) {
				// Exit code 0 means the process exists
			} else {
				// Non-zero exit code means the process doesn't exist
				logInfo("Parent process died, exiting")
				process.exit(0)
			}
		})
	}, 1000) // Check every second
}

void startServer()
