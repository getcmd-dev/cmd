import { LocalExecutable, Message, Tool } from "@/server/schemas/sendMessageSchema"
import { Response } from "express"
import * as acp from "@agentclientprotocol/sdk"

export type ACPToolCall = acp.RequestPermissionRequest["toolCall"]
export type SendMessageToExternalAgent = (
	{
		messages,
		threadId,
		localExecutable,
		tools,
	}: {
		messages: Message[]
		threadId: string
		localExecutable: LocalExecutable
		tools: Tool[]
	},
	res: Response,
) => Promise<void>
