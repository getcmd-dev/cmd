// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Dependencies
import DLS
import Foundation
import JSONFoundation
import ToolFoundation

// MARK: - ClaudeCodeLSTool

public final class ClaudeCodeLSTool: NonStreamableTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    init(
      callingTool: ClaudeCodeLSTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = input
      directoryPath = URL(fileURLWithPath: input.path)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .pendingApproval)
      status = stream
      self.updateStatus = updateStatus
    }

    public struct Input: Codable, Sendable {
      public let path: String
      public let ignore: [String]?
    }

    public struct Output: Codable, Sendable {
      public let content: String
    }

    public let isReadonly = true

    public let callingTool: ClaudeCodeLSTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public func startExecuting() {
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)
      // The execution is managed externally by Claude Code. Nothing to do here.
    }

    public func receive(output: JSON.Value) throws {
      guard case .string(let stringOutput) = output else {
        return
      }
      // Parse the LS output from Claude Code
      // The output is in a tree-like format showing directory structure
      updateStatus.yield(.completed(.success(.init(content: stringOutput))))
    }

    public func reject(reason: String?) {
      updateStatus.yield(.approvalRejected(reason: reason))
    }

    public func cancel() {
      updateStatus.yield(.completed(.failure(CancellationError())))
    }

    let directoryPath: URL

    let context: ToolExecutionContext

    private let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

  }

  public let name = "claude_code_LS"

  public let description = """
    Lists files and directories in a given path. The path parameter must be an absolute path, not a relative path. You can optionally provide an array of glob patterns to ignore with the ignore parameter. You should generally prefer the Glob and Grep tools, if you know which directories to search.
    """

  public var displayName: String {
    "LS (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to list files and directories in a given path."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "path": .object([
          "type": .string("string"),
          "description": .string("The absolute path to the directory to list (must be absolute, not relative)"),
        ]),
        "ignore": .object([
          "type": .string("array"),
          "items": .object([
            "type": .string("string")
          ]),
          "description": .string("List of glob patterns to ignore"),
        ]),
      ]),
      "required": .array([.string("path")]),
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

  public func use(toolUseId: String, input: Use.Input, context: ToolExecutionContext) -> Use {
    Use(callingTool: self, toolUseId: toolUseId, input: input, context: context)
  }

}

// MARK: - LSToolUseViewModel

@Observable
@MainActor
final class LSToolUseViewModel {

  init(status: ClaudeCodeLSTool.Use.Status, input: ClaudeCodeLSTool.Use.Input) {
    self.status = status.value
    self.input = input
    Task { [weak self] in
      for await status in status {
        self?.status = status
      }
    }
  }

  let input: ClaudeCodeLSTool.Use.Input
  var status: ToolUseExecutionStatus<ClaudeCodeLSTool.Use.Output>
}