// Hot server reload utility for command's app development
// This script kills the currently running command's server so it can be restarted with new code
import { exec } from "child_process"
import { ConnectionInfo } from "../src/server/server"
import fs from "fs"
import path from "path"
import os from "os"

/**
 * Executes a shell command and returns the output as a Promise
 * @param command - The shell command to execute
 * @returns Promise that resolves with stdout or rejects with error
 */
function execute(command: string): Promise<string> {
	return new Promise((resolve, reject) => {
		exec(command, (error, stdout) => {
			if (error) {
				reject(error)
			} else {
				resolve(stdout)
			}
		})
	})
}

/**
 * Main function that performs hot reload by killing the current server process
 * The command's app will automatically restart the server when it detects it has died
 */
const hotServerReload = async () => {
	// Read the last connection info to determine which port the server is running on
	// This file is created by the server when it starts up
	const connectionInfoFilePath = path.join(
		os.homedir(),
		"Library/Application Support/dev.getcmd.debug.command/last-connection-info.json",
	)
	const connectionInfo = JSON.parse(fs.readFileSync(connectionInfoFilePath, "utf8")) as ConnectionInfo
	const port = connectionInfo.port

	try {
		// Step 1: Find which process is currently using the server port
		// Using lsof (list open files) to find what's listening on the port
		// jc converts the output to JSON format for easier parsing
		let processInfoString = await execute(`lsof -i :${port} | jc --lsof`)
		let processInfo = JSON.parse(processInfoString) as
			| {
					pid: number
					name: string
					command: string
			  }[]
			| undefined

		// Check if any process was found on the port
		const nodeProcess = processInfo?.filter((process) => process.command === "node")[0]
		if (!nodeProcess) {
			console.log(`No process found on port ${port}`)
			return
		}

		const pid = nodeProcess.pid

		// Step 2: Verify this is actually an command server process
		// Get more detailed info about the process to check its path
		processInfoString = await execute(`lsof -p ${pid} | jc --lsof`)
		processInfo = JSON.parse(processInfoString) as {
			pid: number
			name: string
			command: string
		}[]

		// Double-check that we found process info
		if (!processInfo || processInfo.length === 0) {
			console.log(`No process found on port ${port}`)
			return
		}

		const processName = processInfo[0].name

		// Safety check: only kill processes that are clearly command related
		// This prevents accidentally killing other processes that might be using the same port
		if (!processName.includes("dev.getcmd")) {
			console.log(`Process ${processName} is not a command process`)
			return
		}

		// Step 3: Kill the server process
		// Using kill -9 for forceful termination
		console.log(`Killing process ${processName} with pid ${pid}`)
		await execute(`kill -9 ${pid}`)
	} catch {
		// If any step fails (process not found, permission denied, etc.)
		// Just log and exit gracefully
		console.log(`No process found on port ${port}`)
		return
	}

	// Note: The command app monitors the server process and will automatically
	// restart it when it detects the process has died, picking up any new code changes
}

// Execute the hot reload immediately when this script is run
void hotServerReload()
