export type ApproveToolUseRequestParams = {
	toolUseId: string
	approvalResult: ApprovalResult
}

export type ApprovalResult = ApprovalResultApprove | ApprovalResultDeny

export type ApprovalResultApprove = {
	type: "approval_allowed"
}
export type ApprovalResultDeny = {
	type: "approval_denied"
	reason: string
}
