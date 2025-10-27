import { MessageAttachment } from "@/server/schemas/sendMessageSchema"
import { TextPart } from "ai"

export const attachmentAsPart = (
	attachment: MessageAttachment,
): TextPart | { type: "image"; url: string; mimeType: string } => {
	if (attachment.type === "file_attachment") {
		return {
			text: `<file>
  <path>${attachment.path}</path>
  <content>
  ${attachment.content}
  </content>
</file>`,
			type: "text",
		}
	} else if (attachment.type === "file_selection_attachment") {
		return {
			text: `<file_selection>
  <path>${attachment.path}</path>
  <content>
${attachment.content}
  </content>
  <start_line>${attachment.startLine}</start_line>
  <end_line>${attachment.endLine}</end_line>
</file_selection>`,
			type: "text",
		}
	} else if (attachment.type === "image_attachment") {
		return {
			type: "image",
			url: attachment.url,
			mimeType: attachment.mimeType,
		}
	} else if (attachment.type === "folder_attachment") {
		return {
			type: "text",
			text: `<folder>
  <path>${attachment.path}</path>
  <files>
${attachment.entries.map((content) => content.relativePath).join("\n")}
  </files>
</folder>`,
		}
	} else if (attachment.type === "build_error_attachment") {
		return {
			type: "text",
			text: `Build Error ${attachment.filePath}:${attachment.line}:${attachment.column}: ${attachment.message}`,
		}
	}
	// Unreachable
	throw new Error(`Unknown attachment type: ${(attachment as unknown as { type: string }).type}`)
}
