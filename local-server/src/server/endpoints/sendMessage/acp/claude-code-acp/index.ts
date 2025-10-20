#!/usr/bin/env node

// Load managed settings and apply environment variables
import { loadManagedSettings, applyEnvironmentSettings } from "./utils"
import { runAcp } from "./acp-agent"

export const runAgentInProcess = () => {
	const managedSettings = loadManagedSettings()
	if (managedSettings) {
		applyEnvironmentSettings(managedSettings)
	}

	// stdout is used to send messages to the client
	// we redirect everything else to stderr to make sure it doesn't interfere with ACP
	console.log = console.error
	console.info = console.error
	console.warn = console.error
	console.debug = console.error

	process.on("unhandledRejection", (reason, promise) => {
		console.error("Unhandled Rejection at:", promise, "reason:", reason)
	})

	runAcp()

	// Keep process alive
	process.stdin.resume()
}

// Export all public types and functions that were already exported
export { ClaudeAcpAgent, runAcp } from "./acp-agent"

export { toolInfoFromToolUse, toolUpdateFromToolResult, planEntries, markdownEscape } from "./tools"
export type { ClaudePlanEntry } from "./tools"

export {
	Pushable,
	nodeToWebWritable,
	nodeToWebReadable,
	unreachable,
	sleep,
	loadManagedSettings,
	applyEnvironmentSettings,
	extractLinesWithByteLimit,
} from "./utils"
export type { ExtractLinesResult } from "./utils"

export {
	SYSTEM_REMINDER,
	toolNames,
	createMcpServer,
	createPermissionMcpServer,
	PERMISSION_TOOL_NAME,
	replaceAndCalculateLocation,
} from "./mcp-server"
