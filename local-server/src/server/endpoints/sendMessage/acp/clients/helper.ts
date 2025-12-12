import { LocalExecutable } from "@/server/schemas/sendMessageSchema"
import { ACPTool_Content } from "@/server/schemas/toolsSchema"
import { ToolCallContent } from "@agentclientprotocol/sdk"
import { spawn } from "@/utils/spawn-promise"

export const mapToolCallContent = (toolCall: ToolCallContent): ACPTool_Content => {
	switch (toolCall.type) {
		case "diff": {
			return toolCall
		}
		case "terminal": {
			return toolCall
		}
		case "content": {
			if (toolCall.content.type === "text") {
				return {
					type: "content",
					content: {
						type: "text",
						text: toolCall.content.text,
					},
				}
			} else if (toolCall.content.type === "image") {
				return {
					type: "content",
					content: {
						type: "image",
						data: toolCall.content.data,
						mimeType: toolCall.content.mimeType,
					},
				}
			} else if (toolCall.content.type === "audio") {
				return {
					type: "content",
					content: {
						type: "audio",
						data: toolCall.content.data,
						mimeType: toolCall.content.mimeType,
					},
				}
			} else if (toolCall.content.type === "resource") {
				if ("text" in toolCall.content.resource) {
					return {
						type: "content",
						content: {
							type: "resource",
							resource: {
								type: "embedded_resource_text",
								...toolCall.content.resource,
							},
						},
					}
				} else {
					return {
						type: "content",
						content: {
							type: "resource",
							resource: {
								type: "embedded_resource_blob",
								...toolCall.content.resource,
							},
						},
					}
				}
			} else {
				throw new Error(`Unsupported content type: ${toolCall.content.type}`)
			}
		}
	}
}

// Extract the executable path and args from the LocalExecutable configuration.
// `localExecutable.executable` is a string that may contain the executable name or path along with arguments.
// For instance `claude --dangerously-skip-permissions`
export const extractExecutableInfo = async (
	localExecutable: LocalExecutable,
): Promise<{ path: string; args: string[] }> => {
	const parts = localExecutable.executable.match(/(?:[^\s"]+|"[^"]*")+/g) || []
	const execName = parts[0]?.replace(/(^"|"$)/g, "") // Remove surrounding quotes if any
	const args = parts.slice(1).map((arg) => arg.replace(/(^"|"$)/g, ""))
	if (!execName) {
		throw new Error("Invalid executable path")
	}
	if (execName.startsWith("/")) {
		// absolute path
		return { path: execName, args }
	}
	const execPath = await spawn("which", {
		args: [execName],
		env: localExecutable.env,
		cwd: localExecutable.cwd,
	}).then((r) => r.stdout.trim())
	if (!execPath.length) {
		throw new Error(`Executable ${execName} not found in PATH`)
	}
	return { path: execPath, args }
}
