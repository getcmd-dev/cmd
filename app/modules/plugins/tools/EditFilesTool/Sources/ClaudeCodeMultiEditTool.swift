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
import ThreadSafe
import ToolFoundation

// MARK: - ClaudeCodeMultiEditTool

public final class ClaudeCodeMultiEditTool: ExternalTool {

  public init() { }

  @ThreadSafe
  public final class Use: ExternalToolUse, @unchecked Sendable {
    public init(
      callingTool: ClaudeCodeMultiEditTool,
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
          .error("Claude Code edited a file with no known baseline content. This is unexpected. \(err.localizedDescription)")
      }
    }

    public typealias InternalState = [EditFilesTool.Use.FileChange]
    public struct Input: Codable, Sendable {
      public struct Edit: Codable, Sendable {
        public let old_string: String
        public let new_string: String
        public let replace_all: Bool?
      }

      public let file_path: String
      public let edits: [Edit]
    }

    public typealias Output = EditFilesTool.Use.Output

    public let isReadonly = false

    public let callingTool: ClaudeCodeMultiEditTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public var internalState: InternalState? { mappedInput }

    public func receive(output _: JSON.Value) throws {
      // Placeholder parsing - using placeholder values for now
      let placeholderOutput = "MultiEdit completed successfully"
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
    private var mappedInput: [EditFilesTool.Use.FileChange]

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

  public let name = "claude_code_MultiEdit"

  public let description = """
    This is a tool for making multiple edits to a single file in one operation. It is built on top of the Edit tool and allows you to perform multiple find-and-replace operations efficiently. Prefer this tool over the Edit tool when you need to make multiple edits to the same file.

    Before using this tool:

    1. Use the Read tool to understand the file's contents and context
    2. Verify the directory path is correct

    To make multiple file edits, provide the following:
    1. file_path: The absolute path to the file to modify (must be absolute, not relative)
    2. edits: An array of edit operations to perform, where each edit contains:
       - old_string: The text to replace (must match the file contents exactly, including all whitespace and indentation)
       - new_string: The edited text to replace the old_string
       - replace_all: Replace all occurences of old_string. This parameter is optional and defaults to false.

    IMPORTANT:
    - All edits are applied in sequence, in the order they are provided
    - Each edit operates on the result of the previous edit
    - All edits must be valid for the operation to succeed - if any edit fails, none will be applied
    - This tool is ideal when you need to make several changes to different parts of the same file
    - For Jupyter notebooks (.ipynb files), use the NotebookEdit instead

    CRITICAL REQUIREMENTS:
    1. All edits follow the same requirements as the single Edit tool
    2. The edits are atomic - either all succeed or none are applied
    3. Plan your edits carefully to avoid conflicts between sequential operations

    WARNING:
    - The tool will fail if edits.old_string doesn't match the file contents exactly (including whitespace)
    - The tool will fail if edits.old_string and edits.new_string are the same
    - Since edits are applied in sequence, ensure that earlier edits don't affect the text that later edits are trying to find

    When making edits:
    - Ensure all edits result in idiomatic, correct code
    - Do not leave the code in a broken state
    - Always use absolute file paths (starting with /)
    - Only use emojis if the user explicitly requests it. Avoid adding emojis to files unless asked.
    - Use replace_all for replacing and renaming strings across the file. This parameter is useful if you want to rename a variable for instance.

    If you want to create a new file, use:
    - A new file path, including dir name if needed
    - First edit: empty old_string and the new file's contents as new_string
    - Subsequent edits: normal edit operations on the created content
    """

  public var displayName: String {
    "MultiEdit (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to make multiple edits to a single file in one operation."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "file_path": .object([
          "type": .string("string"),
          "description": .string("The absolute path to the file to modify"),
        ]),
        "edits": .object([
          "type": .string("array"),
          "items": .object([
            "type": .string("object"),
            "properties": .object([
              "old_string": .object([
                "type": .string("string"),
                "description": .string("The text to replace"),
              ]),
              "new_string": .object([
                "type": .string("string"),
                "description": .string("The text to replace it with"),
              ]),
              "replace_all": .object([
                "type": .string("boolean"),
                "default": .bool(false),
                "description": .string("Replace all occurences of old_string (default false)."),
              ]),
            ]),
            "required": .array([.string("old_string"), .string("new_string")]),
            "additionalProperties": .bool(false),
          ]),
          "minItems": .number(1),
          "description": .string("Array of edit operations to perform sequentially on the file"),
        ]),
      ]),
      "required": .array([.string("file_path"), .string("edits")]),
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

}

extension ClaudeCodeMultiEditTool.Use.Input {
  var mappedInput: EditFilesTool.Use.Input {
    EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: file_path.asURLWithPath.path,
        isNewFile: false,
        changes: edits.map { edit in
          EditFilesTool.Use.Input.FileChange.Change(
            search: edit.old_string,
            replace: edit.new_string)
        }),
    ])
  }
}

// MARK: - ClaudeCodeMultiEditTool.Use + DisplayableToolUse

extension ClaudeCodeMultiEditTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    AnyToolUseViewModel(EditFilesToolUseViewModel(
      status: status,
      input: mappedInput,
      isInputComplete: true,
      setResult: { [weak self] toolUseResult in
        guard let self else { return }
        // Update tracked content for successfully applied files
        context.updateFilesContent(changes: toolUseResult.fileChanges, input: mappedInput)
      },
      correctInput: { [weak self] file, fixedInput in
        guard let self else { return }
        mappedInput = mappedInput.correcting(file: file, with: fixedInput)
        updateTrackedFileContent()

        do {
          try chatContextRegistry.context(for: context.threadId).requestPersistence()
        } catch {
          defaultLogger.error("Failed to persist thread")
        }
      }))
  }
}
