// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import Foundation
import JSONFoundation
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeGlobTool

public final class ClaudeCodeGlobTool: ExternalTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    public init(
      callingTool: ClaudeCodeGlobTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
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

    public typealias InternalState = EmptyObject
    public struct Input: Codable, Sendable {
      public let pattern: String
      public let path: String?
    }

    public struct Output: Codable, Sendable {
      public let files: [String]
    }

    public let isReadonly = true

    public let callingTool: ClaudeCodeGlobTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func receive(output: JSON.Value) throws {
      let output = try requireStringOutput(from: output)
      // Parse the glob output from Claude Code
      // The output is newline-separated file paths
      let files = output
        .split(separator: "\n")
        .map(String.init)
        .filter { !$0.isEmpty }

      updateStatus.complete(with: .success(.init(files: files)))
    }

  }

  public let name = "claude_code_Glob"

  public let description = """
    - Fast file pattern matching tool that works with any codebase size
    - Supports glob patterns like "**/*.js" or "src/**/*.ts"
    - Returns matching file paths sorted by modification time
    - Use this tool when you need to find files by name patterns
    - When you are doing an open ended search that may require multiple rounds of globbing and grepping, use the Agent tool instead
    - You have the capability to call multiple tools in a single response. It is always better to speculatively perform multiple searches as a batch that are potentially useful.
    """

  public var displayName: String {
    "Glob (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to find files by pattern matching using glob syntax."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "pattern": .object([
          "type": .string("string"),
          "description": .string("The glob pattern to match files against"),
        ]),
        "path": .object([
          "type": .string("string"),
          "description": .string(
            "The directory to search in. If not specified, the current working directory will be used. IMPORTANT: Omit this field to use the default directory. DO NOT enter \"undefined\" or \"null\" - simply omit it for the default behavior. Must be a valid directory path if provided."),
        ]),
      ]),
      "required": .array([.string("pattern")]),
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

}

// MARK: - GlobToolUseViewModel

@Observable
@MainActor
final class GlobToolUseViewModel {

  init(status: ClaudeCodeGlobTool.Use.Status, input: ClaudeCodeGlobTool.Use.Input) {
    self.status = status.value
    self.input = input
    Task { [weak self] in
      for await status in status.futureUpdates {
        self?.status = status
      }
    }
  }

  let input: ClaudeCodeGlobTool.Use.Input
  var status: ToolUseExecutionStatus<ClaudeCodeGlobTool.Use.Output>
}

// MARK: ViewRepresentable, StreamRepresentable

extension GlobToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(GlobToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(let result) = status else { return nil }
    switch result {
    case .success(let output):
      return """
        ⏺ Glob(\(input.pattern))
          ⎿ Found \(output.files.count) files


        """

    case .failure(let error):
      return """
        ⏺ Glob(\(input.pattern))
          ⎿ Failed: \(error.localizedDescription)


        """
    }
  }
}
