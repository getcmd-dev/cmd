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

// MARK: - ClaudeCodeLSTool

public final class ClaudeCodeLSTool: ExternalTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    public init(
      callingTool: ClaudeCodeLSTool,
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
      directoryPath = URL(fileURLWithPath: input.path)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject
    public struct Input: Codable, Sendable {
      public let path: String
      public let ignore: [String]?
    }

    public typealias Output = LSTool.Use.Output

    public let isReadonly = true

    public let callingTool: ClaudeCodeLSTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func receive(output: JSON.Value) throws {
      let output = try requireStringOutput(from: output)
      updateStatus.complete(with: .success(parse(rawOutput: output)))
    }

    let directoryPath: URL

    /// Parse the LS output from Claude Code
    /// The output is in a tree-like format showing directory structure and some optional comments, like:
    /// ```
    ///  - /Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Tests/
    ///    - ../
    ///      - Module.swift
    ///      - Sources/
    ///        - ClaudeCodeReadTool.swift
    ///        - ClaudeCodeReadToolView+Preview.swift
    ///        - ClaudeCodeReadToolView.swift
    ///        - Content.swift
    ///    - ClaudeCodeReadToolEncodingTests.swift
    ///    - ClaudeCodeReadToolTests.swift
    ///
    ///  build the list of full path
    /// ```
    private func parse(rawOutput: String) -> Output {
      // Given a string like

      var pathComponents: [(Int, String)] = [(0, directoryPath.path)]
      var paths = [[String]]()

      for line in rawOutput.components(separatedBy: .newlines) {
        // Count leading spaces to determine nesting level
        let leadingSpaces = line.prefix(while: { $0 == " " }).count

        let startIndex = line.index(line.startIndex, offsetBy: leadingSpaces)
        guard
          leadingSpaces < line.count - 1,
          line[startIndex] == "-"
        else { continue } // Only process lines containing "- " after the leading spaces.

        let afterDashIndex = line.index(startIndex, offsetBy: 2)

        let newPathComponent = String(line[afterDashIndex...]).trimmingCharacters(in: .whitespaces)
        while let lastPathComponent = pathComponents.last, lastPathComponent.0 >= leadingSpaces {
          pathComponents.removeLast()
        }
        pathComponents.append((leadingSpaces, newPathComponent))
        paths.append(pathComponents.map(\.1))
      }

      let files = paths.map { components in
        let absolutePathIdx = components.lastIndex(where: { $0.hasPrefix("/") }) ?? 0
        var url = URL(fileURLWithPath: components[absolutePathIdx])
        for component in components.dropFirst(absolutePathIdx + 1) {
          url.appendPathComponent(component)
        }
        return Output.File(path: url.standardized.path, attr: nil, size: nil)
      }

      return Output(files: files, hasMore: false)
    }

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
            "type": .string("string"),
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

}

// MARK: - ClaudeCodeLSTool.Use + DisplayableToolUse

extension ClaudeCodeLSTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    AnyToolUseViewModel(ToolUseViewModel(
      status: status,
      directoryPath: directoryPath,
      projectRoot: context.projectRoot))
  }
}
