export interface SendMessageRequestParams {
	messages: Message[]
	system?: string
	projectRoot: string | undefined
	tools?: Tool[]
	model: string
	enableReasoning: boolean
	provider: APIProvider
	threadId: string | undefined
}

export interface APIProvider {
	name: APIProviderName
	settings: {
		apiKey?: string
		baseUrl?: string
		localExecutable?: LocalExecutable
	}
}

export interface LocalExecutable {
	executable: string
	env: Record<string, string>
	cwd?: string
}

export type APIProviderName = "openai" | "anthropic" | "openrouter" | "claude_code"

export type StreamedResponseChunk =
	| TextDelta
	| ToolUseRequest
	| ToolUseDelta
	| ToolResultMessage // When interacting with an external agent, like Claude Code, the tool results are produced externally and sent back to the host application.
	| ResponseError
	| ReasoningDelta
	| ReasoningSignature
	| ResponseUsage
	| Ping
	| InternalContent

export interface TextDelta {
	type: "text_delta"
	text: string
	/**
	 * @format integer
	 */
	idx: number
}

export interface Ping {
	type: "ping"
	timestamp: number
	/**
	 * @format integer
	 */
	idx: number
}

export interface ToolUseRequest {
	type: "tool_call"
	toolName: string
	input: Record<string, unknown>
	toolUseId: string
	/**
	 * @format integer
	 */
	idx: number
}

export interface ToolUseDelta {
	type: "tool_call_delta"
	toolName: string
	inputDelta: string
	toolUseId: string
	/**
	 * @format integer
	 */
	idx: number
}

export interface ReasoningDelta {
	type: "reasoning_delta"
	delta: string
	/**
	 * @format integer
	 */
	idx: number
}
export interface ReasoningSignature {
	type: "reasoning_signature"
	signature: string
	/**
	 * @format integer
	 */
	idx: number
}

export interface ResponseError {
	type: "error"
	message: string
	/**
	 * @format integer
	 */
	statusCode?: number
	/**
	 * @format integer
	 */
	idx?: number
}

export interface ResponseUsage {
	type: "usage"
	/**
	 * @format integer
	 */
	inputTokens: number
	/**
	 * @format integer
	 */
	outputTokens: number
	/**
	 * @format integer
	 */
	idx: number
}

/**
 * An opaque message that the local server sends to the host app for it to be sent back in the next turn.
 * This can be helpful for the local server to remain stateless while later receiving the required information (somewhat similar to a session cookie).
 */
export interface InternalContent {
	type: "internal_content"
	/**
	 * The content of the message that should be preserved.
	 */
	value: Record<string, unknown>

	/**
	 * @format integer
	 */
	idx: number
}

export type MessageContent =
	| TextMessage
	| ReasoningMessage
	| ToolUseRequest
	| ToolResultMessage
	| InternalTextMessage
	| InternalContent

export interface Message {
	// The role of the message's author. Roles can be: system, user, assistant, function or tool.
	role: "system" | "user" | "assistant" | "tool"
	content: Array<MessageContent>
	// | ImageBlockParam
}
// export interface ImageBlockParam {
//   type: 'image';
//   source: ImageSource;
// }

// export interface ImageSource {
//   data: string;
//   media_type: 'image/jpeg' | 'image/png' | 'image/gif' | 'image/webp';
//   type: 'base64';
// }

export interface TextMessage {
	text: string
	attachments?: MessageAttachment[]
	type: "text"
}

export interface ReasoningMessage {
	text: string
	signature?: string
	type: "reasoning"
}

// This should not be sent to the provider. Can be used to hold internal information.
export interface InternalTextMessage {
	text: string
	type: "internal_text"
}

export type MessageAttachment = ImageAttachment | FileAttachment | FileSelectionAttachment | BuildErrorAttachment

export interface ImageAttachment {
	type: "image_attachment"
	url: string
	mimeType: string
}

export interface FileAttachment {
	type: "file_attachment"
	path: string
	content: string
}

export interface FileSelectionAttachment {
	type: "file_selection_attachment"
	path: string
	content: string
	/**
	 * @format integer
	 */
	startLine: number
	/**
	 * @format integer
	 */
	endLine: number
}

export interface BuildErrorAttachment {
	type: "build_error_attachment"
	filePath: string
	/**
	 * @format integer
	 */
	line: number
	/**
	 * @format integer
	 */
	column: number
	message: string
}

export interface ToolResultSuccessMessage {
	type: "tool_result_success"
	success: unknown
}

export interface ToolResultFailureMessage {
	type: "tool_result_failure"
	failure: unknown
}

export interface ToolResultMessage {
	type: "tool_result"
	toolUseId: string
	toolName: string
	result: ToolResultSuccessMessage | ToolResultFailureMessage
	/**
	 * @format integer
	 */
	idx?: number
}

export interface Tool {
	name: string
	description: string
	inputSchema: Record<string, unknown>
}

export interface ChatCompletionToolResponseChunk {
	type: "tool_call"
	id: string
	input: Record<string, unknown>
	name: string
}
