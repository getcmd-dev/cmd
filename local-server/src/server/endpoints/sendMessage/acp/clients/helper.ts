import { ACPTool_Content } from "@/server/schemas/toolsSchema"
import { ToolCallContent } from "@agentclientprotocol/sdk"

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
