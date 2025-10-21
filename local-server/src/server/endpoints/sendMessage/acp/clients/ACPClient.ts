import { ContentBlock, SessionNotification } from "@agentclientprotocol/sdk"
import {
	Message,
	ReasoningDelta,
	TextDelta,
	ToolResultMessage,
	ToolUsePermissionRequest,
	ToolUseRequest,
} from "@/server/schemas/sendMessageSchema"
import { ResponseChunkWithoutIndex } from "../../sendMessage"
import { logError, logInfo } from "@/logger"
import { ApprovalResult, ApproveToolUseRequestParams } from "@/server/schemas/toolApprovalSchema"
import { Request, Response, Router } from "express"
import { UserFacingError } from "@/server/errors"
import { AsyncStream } from "@/utils/asyncStream"

const pendingToolApprovalRequests = new Map<string, (result: ApprovalResult) => void>()

export interface ACPClient<SessionInitializationParams extends { cwd: string }> {
	prompt(
		sessionInitializationParams: SessionInitializationParams,
		message: ContentBlock[],
		threadId: string,
		permissionRequestHandler: ({
			toolCallId,
			input,
			toolName,
		}: {
			toolCallId: string
			input: unknown
			toolName: string
		}) => Promise<boolean>,
		abortController?: AbortController,
	): Promise<AsyncIterable<SessionNotification>>
}

export const toACPContentBlocks = (messages: Message[]): ContentBlock[] => {
	const result: ContentBlock[] = []
	messages.forEach((message) => {
		message.content.forEach((content) => {
			if (content.type === "text") {
				result.push({
					text: content.text,
					type: "text",
				})
				content.attachments?.forEach((attachment) => {
					if (attachment.type === "file_attachment") {
						result.push({
							text: `<file_attachment>
								<path>${attachment.path}</path>
								<content>${attachment.content}</content>
							</file_attachment>`,
							type: "text",
						})
					} else if (attachment.type === "file_selection_attachment") {
						result.push({
							text: `<file_selection_attachment>
								<path>${attachment.path}</path>
								<selection>${attachment.content}</selection>
								<start_line>${attachment.startLine}</start_line>
								<end_line>${attachment.endLine}</end_line>
							</file_selection_attachment>`,
							type: "text",
						})
					} else if (attachment.type === "image_attachment") {
						// Remove the data URL prefix if present (e.g., "data:image/png;base64,")
						const base64Data = attachment.url.replace(/^data:image\/\w+;base64,/, "")
						const fileExtension = attachment.mimeType.split("/").pop()
						const mediaType: "image/jpeg" | "image/png" | "image/gif" | "image/webp" = (() => {
							switch (fileExtension) {
								case "png":
									return "image/png"
								case "jpg":
									return "image/jpeg"
								case "gif":
									return "image/gif"
								case "webp":
									return "image/webp"
								default:
									return "image/png"
							}
						})()
						result.push({
							type: "image",
							data: base64Data,
							mimeType: mediaType,
						})
					}
				})
			}
		})
	})
	return result
}

export async function* toMessageStream(
	stream: AsyncIterable<SessionNotification>,
): AsyncIterable<ResponseChunkWithoutIndex> {
	let hasSentSessionId = false

	for await (const event of stream) {
		const externalSessionId = event._meta?.externalSessionId as string | undefined
		if (!hasSentSessionId && externalSessionId) {
			hasSentSessionId = true
			yield {
				type: "internal_content",
				value: {
					type: "session_id",
					sessionId: externalSessionId,
				} satisfies SessionIdInfo,
			}
		}
		switch (event.update.sessionUpdate) {
			case "agent_message_chunk": {
				if (event.update.content.type === "text") {
					yield {
						type: "text_delta",
						text: event.update.content.text,
					} satisfies Omit<TextDelta, "idx">
				} else {
					logError(
						`Ignoring unsupported content type for ${event.update.sessionUpdate}: ${event.update.content.type}`,
					)
				}
				break
			}
			case "agent_thought_chunk": {
				if (event.update.content.type === "text") {
					yield {
						type: "reasoning_delta",
						delta: event.update.content.text,
					} satisfies Omit<ReasoningDelta, "idx">
				} else {
					logError(
						`Ignoring unsupported content type for ${event.update.sessionUpdate}: ${event.update.content.type}`,
					)
				}
				break
			}
			case "user_message_chunk": {
				break
			}
			case "tool_call": {
				const toolName = event.update._meta?.toolName
				if (typeof toolName !== "string") {
					// TODO: handle regular ACP tools whose name has been removed
					// as this will be necessary when integrating with agents that we can't modify easily,
					// like codex that is Rust
					logError(`Tool call without tool name: ${JSON.stringify(event.update, null, 2)}`)
					break
				}
				const input = event.update._meta?.input as Record<string, unknown> | undefined
				yield {
					type: "tool_call",
					toolName,
					toolUseId: event.update.toolCallId,
					input: input || event.update.rawInput || {},
				} satisfies Omit<ToolUseRequest, "idx">
				break
			}
			case "tool_call_update": {
				if (event.update.status === "completed" || event.update.status === "failed") {
					const toolName = event.update._meta?.toolName
					if (typeof toolName !== "string") {
						// TODO: handle regular ACP tools whose name has been removed
						// as this will be necessary when integrating with agents that we can't modify easily,
						// like codex that is Rust
						logError(`Tool call without tool name: ${JSON.stringify(event.update, null, 2)}`)
						break
					}

					const output: unknown =
						(event.update._meta?.output as Record<string, unknown> | undefined) ||
						event.update._meta?.jsonOutput ||
						event.update.rawOutput ||
						{}

					yield {
						type: "tool_result",
						toolUseId: event.update.toolCallId,
						toolName,
						result:
							event.update.status === "completed"
								? {
										type: "tool_result_success",
										success: output,
									}
								: {
										type: "tool_result_failure",
										failure: output,
									},
					} satisfies Omit<ToolResultMessage, "idx">
				}
				break
			}
			case "plan": {
				break
			}
			case "available_commands_update": {
				break
			}
			case "current_mode_update": {
				break
			}
			default: {
				break
			}
		}
	}
}

type SessionIdInfo = {
	type: "session_id"
	sessionId: string
}

export const askAppForPermission = async ({
	toolCallId,
	input,
	toolName,
	eventStream,
}: {
	toolCallId: string
	input: unknown
	toolName: string
	eventStream: AsyncStream<ResponseChunkWithoutIndex>
}): Promise<boolean> => {
	logInfo(`Received permission request for ${toolCallId}: ${JSON.stringify(input, null, 2)}`)

	const response = await new Promise<ApprovalResult>((resolve) => {
		pendingToolApprovalRequests.set(toolCallId, resolve)

		eventStream.yield({
			type: "tool_use_permission_request",
			toolName,
			toolUseId: toolCallId,
			input: input as Record<string, unknown>,
		} satisfies Omit<ToolUsePermissionRequest, "idx">)
	})

	return response.type === "approval_allowed"
}

export const registerEndpoint = (router: Router) => {
	// This endpoint is used to receive the result of pending tool permission requests.
	router.post("/sendMessage/toolUse/permission/acp", async (req: Request, res: Response) => {
		const body = req.body as ApproveToolUseRequestParams
		const { toolUseId, approvalResult } = body

		if (!toolUseId || typeof toolUseId !== "string") {
			throw new UserFacingError({
				message: "Invalid toolUseId",
				statusCode: 400,
			})
		}

		if (!approvalResult || !approvalResult.type) {
			throw new UserFacingError({
				message: "Invalid approvalResult",
				statusCode: 400,
			})
		}

		logInfo(`Received tool use permission response: ${toolUseId}, ${JSON.stringify(approvalResult)}.`)

		const pendingRequest = pendingToolApprovalRequests.get(toolUseId)
		if (!pendingRequest) {
			throw new UserFacingError({
				message: `No pending tool use approval request found for tool use ${toolUseId}`,
				statusCode: 404,
			})
		}

		// Remove from pending requests and resolve
		pendingToolApprovalRequests.delete(toolUseId)
		pendingRequest(approvalResult)
		res.json({ success: true })
	})
}
