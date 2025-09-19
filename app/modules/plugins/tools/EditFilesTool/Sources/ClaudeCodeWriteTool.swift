// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import Foundation
import FoundationInterfaces
import JSONFoundation
import LoggingServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeWriteTool

public final class ClaudeCodeWriteTool: ExternalTool {

  public init() { }

  public final class Use: ExternalToolUse, @unchecked Sendable {
    public init(
      callingTool: ClaudeCodeWriteTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState: InternalState? = nil,
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

      // Set the baseline content using the last known value.
      // Claude Code doesn't allow updates prior to a read, so this is safe.

      let (mappedInput, err) = context.mappedInput(
        persistedInput: internalState,
        rawInput: input.mappedInput,
        validateFileContent: false)
      self.mappedInput = mappedInput
      if let err {
        defaultLogger
          .error("Claude Code wrote a file with no known baseline content. This is unexpected. \(err.localizedDescription)")
      }
      chatContextRegistry.persist(thread: context.threadId)
    }

    public typealias InternalState = [EditFilesTool.Use.FileChange]
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

    public var internalState: InternalState? { mappedInput }

    public func receive(output _: JSON.Value) throws {
      // Placeholder parsing - using placeholder values for now
      let placeholderOutput = "Write completed successfully"
      // TODO: handle failures
      updateStatus.complete(with: .success(placeholderOutput))

      updateTrackedFileContent()
      Task { [weak self] in
        // It seems that Claude Code can send the result of the file edit before the file has been updated on disk,
        // which is surprising.
        // We re-update the file content 1s later to work around this.
        try await Task.sleep(nanoseconds: 1_000_000)
        self?.updateTrackedFileContent()
      }
    }

    @Dependency(\.chatContextRegistry) private var chatContextRegistry
    @Dependency(\.fileManager) private var fileManager
    private let mappedInput: [FileChange]

    private func updateTrackedFileContent() {
      do {
        let context = try chatContextRegistry.context(for: context.threadId)
        try mappedInput.forEach { change in
          let fileContent = try fileManager.read(contentsOf: change.path)
          context.set(knownFileContent: fileContent, for: change.path)
        }
      } catch {
        defaultLogger.error("Failed to update tracked file content", error)
      }
    }

  }

  public let name = "claude_code_Write"

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

extension ClaudeCodeWriteTool.Use.Input {
  var mappedInput: EditFilesTool.Use.Input {
    EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: file_path.asURLWithPath.path,
        isNewFile: true,
        changes: [
          EditFilesTool.Use.Input.FileChange.Change(
            search: "",
            replace: content),
        ]),
    ])
  }
}

// MARK: - ClaudeCodeWriteTool.Use + DisplayableToolUse

extension ClaudeCodeWriteTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    AnyToolUseViewModel(EditFilesToolUseViewModel(
      status: status,
      input: mappedInput,
      isInputComplete: true,
      setResult: { [weak self] toolUseResult in
        guard let self else { return }
        // Update tracked content for successfully applied files
        context.updateFilesContent(changes: toolUseResult.fileChanges, input: mappedInput)
      }))
  }
}
