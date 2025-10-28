import { MessageAttachment } from "@/server/schemas/sendMessageSchema"
import { attachmentAsPart } from "./helpers"

describe("attachmentAsPart", () => {
	describe("file_attachment", () => {
		test("should convert file attachment to XML text format", () => {
			const attachment: MessageAttachment = {
				type: "file_attachment",
				path: "/project/main.swift",
				content: 'print("Hello, world!")',
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: `<file>
  <path>/project/main.swift</path>
  <content>
  print("Hello, world!")
  </content>
</file>`,
			})
		})

		test("should handle multiline file content", () => {
			const attachment: MessageAttachment = {
				type: "file_attachment",
				path: "/src/example.ts",
				content: `function example() {
  return 42;
}`,
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: `<file>
  <path>/src/example.ts</path>
  <content>
  function example() {
  return 42;
}
  </content>
</file>`,
			})
		})

		test("should handle empty file content", () => {
			const attachment: MessageAttachment = {
				type: "file_attachment",
				path: "/empty.txt",
				content: "",
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: `<file>
  <path>/empty.txt</path>
  <content>
  
  </content>
</file>`,
			})
		})
	})

	describe("file_selection_attachment", () => {
		test("should convert file selection attachment to XML text format", () => {
			const attachment: MessageAttachment = {
				type: "file_selection_attachment",
				path: "/code.swift",
				content: "line 2\nline 3\nline 4",
				startLine: 2,
				endLine: 4,
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: `<file_selection>
  <path>/code.swift</path>
  <content>
line 2
line 3
line 4
  </content>
  <start_line>2</start_line>
  <end_line>4</end_line>
</file_selection>`,
			})
		})

		test("should handle single line selection", () => {
			const attachment: MessageAttachment = {
				type: "file_selection_attachment",
				path: "/single.ts",
				content: "const x = 42;",
				startLine: 10,
				endLine: 10,
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: `<file_selection>
  <path>/single.ts</path>
  <content>
const x = 42;
  </content>
  <start_line>10</start_line>
  <end_line>10</end_line>
</file_selection>`,
			})
		})
	})

	describe("image_attachment", () => {
		test("should convert image attachment to image format", () => {
			const attachment: MessageAttachment = {
				type: "image_attachment",
				url: "data:image/png;base64,iVBORw0KG...",
				mimeType: "image/png",
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "image",
				url: "data:image/png;base64,iVBORw0KG...",
				mimeType: "image/png",
			})
		})

		test("should handle image with path", () => {
			const attachment: MessageAttachment = {
				type: "image_attachment",
				url: "data:image/jpeg;base64,/9j/4AAQ...",
				mimeType: "image/jpeg",
				path: "/screenshots/screenshot.jpg",
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "image",
				url: "data:image/jpeg;base64,/9j/4AAQ...",
				mimeType: "image/jpeg",
			})
		})
	})

	describe("folder_attachment", () => {
		test("should convert folder attachment to XML text format", () => {
			const attachment: MessageAttachment = {
				type: "folder_attachment",
				path: "/project/src",
				entries: [
					{ path: "/project/src/main.swift", relativePath: "main.swift" },
					{ path: "/project/src/utils.swift", relativePath: "utils.swift" },
				],
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: `<folder>
  <path>/project/src</path>
  <files>
main.swift
utils.swift
  </files>
</folder>`,
			})
		})

		test("should handle empty folder", () => {
			const attachment: MessageAttachment = {
				type: "folder_attachment",
				path: "/empty",
				entries: [],
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: `<folder>
  <path>/empty</path>
  <files>

  </files>
</folder>`,
			})
		})

		test("should handle folder with nested paths", () => {
			const attachment: MessageAttachment = {
				type: "folder_attachment",
				path: "/project",
				entries: [
					{ path: "/project/Package.swift", relativePath: "Package.swift" },
					{ path: "/project/Sources/MyLib/File.swift", relativePath: "Sources/MyLib/File.swift" },
					{ path: "/project/Tests/MyLibTests.swift", relativePath: "Tests/MyLibTests.swift" },
				],
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: `<folder>
  <path>/project</path>
  <files>
Package.swift
Sources/MyLib/File.swift
Tests/MyLibTests.swift
  </files>
</folder>`,
			})
		})

		test("should handle folder with hasMoreContent flag", () => {
			const attachment: MessageAttachment = {
				type: "folder_attachment",
				path: "/large",
				entries: Array.from({ length: 50 }, (_, i) => ({
					path: `/large/file${i + 1}.swift`,
					relativePath: `file${i + 1}.swift`,
				})),
				hasMoreContent: true,
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: expect.stringContaining("<folder>"),
			})
			expect(result).toEqual({
				type: "text",
				text: expect.stringContaining("<path>/large</path>"),
			})
			expect(result).toEqual({
				type: "text",
				text: expect.stringContaining("file1.swift"),
			})
			expect(result).toEqual({
				type: "text",
				text: expect.stringContaining("file50.swift"),
			})
		})
	})

	describe("build_error_attachment", () => {
		test("should convert build error attachment to plain text format", () => {
			const attachment: MessageAttachment = {
				type: "build_error_attachment",
				filePath: "/broken.swift",
				line: 42,
				column: 10,
				message: "Type 'String' has no member 'foo'",
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: "Build Error /broken.swift:42:10: Type 'String' has no member 'foo'",
			})
		})

		test("should handle build error with multiline message", () => {
			const attachment: MessageAttachment = {
				type: "build_error_attachment",
				filePath: "/code.ts",
				line: 15,
				column: 5,
				message: "Cannot find name 'x'.\nDid you mean 'y'?",
			}

			const result = attachmentAsPart(attachment)

			expect(result).toEqual({
				type: "text",
				text: "Build Error /code.ts:15:5: Cannot find name 'x'.\nDid you mean 'y'?",
			})
		})
	})

	describe("error handling", () => {
		test("should throw error for unknown attachment type", () => {
			const attachment = {
				type: "unknown_type",
			} as unknown as MessageAttachment

			expect(() => attachmentAsPart(attachment)).toThrow("Unknown attachment type: unknown_type")
		})
	})
})
