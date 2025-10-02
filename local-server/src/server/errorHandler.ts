import { Request, Response, NextFunction } from "express"
import { logError } from "../logger"

// Catch all errors during the execution to avoid crashing the server, and return a 500 error instead.
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const errorHandler = (err: Error & { statusCode?: number }, req: Request, res: Response, next: NextFunction) => {
	const errStatus = err.statusCode || 500
	const errMsg = err.message || "Something went wrong"

	logError(`Request failed: ${errMsg}`, err)
	const errorInfo = {
		type: "error",
		success: false,
		statusCode: errStatus,
		message: errMsg,
		stack: process.env.NODE_ENV === "development" ? err.stack : {},
	}

	// If headers have already been sent, we need to handle differently
	if (res.headersSent) {
		// Check if this is an SSE response (text/event-stream)
		if (res.getHeader("Content-Type") === "text/event-stream") {
			try {
				// Send error as SSE event and end the stream
				res.write(`data: ${JSON.stringify(errorInfo)}\n\n`)
				res.end()
			} catch (writeError) {
				// If we can't write to the response, just log the error
				logError(`Failed to write SSE error`, writeError)
			}
		} else {
			// For regular responses where headers are already sent, we can't do much
			// Just log the error and let Express handle it
			logError(`Cannot send error response - headers already sent for non-SSE response`)
		}
		return
	}

	// Headers haven't been sent yet, so we can send a proper error response
	res.status(errStatus)

	if (res.getHeader("Content-Type") === "text/event-stream") {
		// Format the error according to SSE protocol if this is an SSE connection
		res.write(`data: ${JSON.stringify(errorInfo)}\n\n`)
		res.end()
	} else {
		// For regular JSON responses
		res.json(errorInfo)
	}
}

export default errorHandler
