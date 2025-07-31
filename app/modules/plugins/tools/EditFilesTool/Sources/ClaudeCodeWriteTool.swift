// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import Foundation
import JSONFoundation
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeWriteTool

public final class ClaudeCodeWriteTool: ExternalTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    public init(
      callingTool: ClaudeCodeWriteTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = input

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public struct Input: Codable, Sendable {
      public let file_path: String
      public let content: String
    }

    public typealias Output = EditFilesTool.Use.Output

    public let isReadonly = false

    public let callingTool: ClaudeCodeWriteTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func receive(output _: String) throws {
      // Placeholder parsing - using placeholder values for now
      let placeholderOutput = Output(result: JSON.object(["status": .string("Write completed successfully")]))
      updateStatus.complete(with: .success(placeholderOutput))
    }

  }

  public let name = "Write"

  public let description = """
    Writes a file to the local filesystem.

    Usage:
    - This tool will overwrite the existing file if there is one at the provided path.
    - If this is an existing file, you MUST use the Read tool first to read the file's contents. This tool will fail if you did not read the file first.
    - ALWAYS prefer editing existing files in the codebase. NEVER write new files unless explicitly required.
    - NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
    - Only use emojis if the user explicitly requests it. Avoid writing emojis to files unless asked.
    """

  public var displayName: String {
    "Write (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to write files to the local filesystem."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "file_path": .object([
          "type": .string("string"),
          "description": .string("The absolute path to the file to write (must be absolute, not relative)"),
        ]),
        "content": .object([
          "type": .string("string"),
          "description": .string("The content to write to the file"),
        ]),
      ]),
      "required": .array([.string("file_path"), .string("content")]),
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

}

// MARK: - ClaudeCodeWriteTool.Use + DisplayableToolUse

extension ClaudeCodeWriteTool.Use: DisplayableToolUse {
  public var body: AnyView {
    // Create a compatible EditFilesTool.Use.Input for reusing the existing view
    let editFilesInput = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: input.file_path,
        isNewFile: true,
        changes: [
          EditFilesTool.Use.Input.FileChange.Change(
            search: "",
            replace: input.content),
        ],
        baseLineContent: nil),
    ])

    let viewModel = ToolUseViewModel(
      status: status,
      input: editFilesInput,
      isInputComplete: true,
      updateToolStatus: { _ in },
      syncBaselineContent: { _, _ in })

    return AnyView(ToolUseView(toolUse: viewModel))
  }
}
