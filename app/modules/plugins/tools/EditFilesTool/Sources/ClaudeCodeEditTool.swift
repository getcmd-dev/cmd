// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import DLS
import Foundation
import JSONFoundation
import LoggingServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeEditTool

public final class ClaudeCodeEditTool: ExternalTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    public init(
      callingTool: ClaudeCodeEditTool,
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
      public let file_path: String
      public let old_string: String
      public let new_string: String
      public let replace_all: Bool?
    }

    public typealias Output = EditFilesTool.Use.Output

    public let isReadonly = false

    public let callingTool: ClaudeCodeEditTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext
    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public var internalState: InternalState? { mappedInput }

    public func receive(output _: String) throws {
      // Placeholder parsing - using placeholder values for now
      let placeholderOutput = "Edit completed successfully"
      // TODO: handle failures
      updateStatus.complete(with: .success(placeholderOutput))
    }

    private let mappedInput: [FileChange]

  }

  public let name = "claude_code_Edit"

  public let description = """
    Performs exact string replacements in files. 

    Usage:
    - You must use your `Read` tool at least once in the conversation before editing. This tool will error if you attempt an edit without reading the file. 
    - When editing text from Read tool output, ensure you preserve the exact indentation (tabs/spaces) as it appears AFTER the line number prefix. The line number prefix format is: spaces + line number + tab. Everything after that tab is the actual file content to match. Never include any part of the line number prefix in the old_string or new_string.
    - ALWAYS prefer editing existing files in the codebase. NEVER write new files unless explicitly required.
    - Only use emojis if the user explicitly requests it. Avoid adding emojis to files unless asked.
    - The edit will FAIL if `old_string` is not unique in the file. Either provide a larger string with more surrounding context to make it unique or use `replace_all` to change every instance of `old_string`. 
    - Use `replace_all` for replacing and renaming strings across the file. This parameter is useful if you want to rename a variable for instance.
    """

  public var displayName: String {
    "Edit (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to perform exact string replacements in files."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "file_path": .object([
          "type": .string("string"),
          "description": .string("The absolute path to the file to modify"),
        ]),
        "old_string": .object([
          "type": .string("string"),
          "description": .string("The text to replace"),
        ]),
        "new_string": .object([
          "type": .string("string"),
          "description": .string("The text to replace it with (must be different from old_string)"),
        ]),
        "replace_all": .object([
          "type": .string("boolean"),
          "default": .bool(false),
          "description": .string("Replace all occurences of old_string (default false)"),
        ]),
      ]),
      "required": .array([.string("file_path"), .string("old_string"), .string("new_string")]),
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

}

// MARK: - ClaudeCodeEditTool.Use + DisplayableToolUse

extension ClaudeCodeEditTool.Use.Input {
  var mappedInput: EditFilesTool.Use.Input {
    EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: file_path.asURLWithPath.path,
        isNewFile: false,
        changes: [
          EditFilesTool.Use.Input.FileChange.Change(
            search: old_string,
            replace: new_string),
        ]),
    ])
  }
}

extension ClaudeCodeEditTool.Use: DisplayableToolUse {
  public var body: AnyView {
    let viewModel = ToolUseViewModel(
      status: status,
      input: mappedInput,
      isInputComplete: true,
      setResult: { _ in })

    return AnyView(ToolUseView(toolUse: viewModel))
  }
}
