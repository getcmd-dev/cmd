import { ApprovalResult } from "@/server/schemas/toolApprovalSchema"

/**
 * Shared map to track pending tool approval requests across both old and new Claude Code implementations.
 * Key: toolUseId, Value: resolver function to respond with approval result
 */
export const pendingToolApprovalRequests = new Map<string, (result: ApprovalResult) => void>()
