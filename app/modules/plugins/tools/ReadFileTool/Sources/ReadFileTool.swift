// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatServiceInterface
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import FoundationInterfaces
import JSONFoundation
import LoggingServiceInterface
import SwiftUI
import ThreadSafe
import ToolFoundation

// MARK: - ReadFileTool

public final class ReadFileTool: NonStreamableTool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: NonStreamableToolUse, UpdatableToolUse, @unchecked Sendable {
    public init(
      callingTool: ReadFileTool,
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
      resolvedInput = internalState ?? Input(
        path: input.path.resolvePath(from: context.projectRoot).path,
        lineRange: input.lineRange)
      filePath = URL(fileURLWithPath: resolvedInput.path)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = Input
    public struct Input: Codable, Sendable {
      public let path: String
      public let lineRange: Range?
      public struct Range: Codable, Sendable {
        public let start: Int
        public let end: Int
      }
    }

    public struct Output: Codable, Sendable {
      public let content: String
      public let uri: String
    }

    public let resolvedInput: InternalState
    public let isReadonly = true

    public let callingTool: ReadFileTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public var internalState: InternalState? { resolvedInput }

    public func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)

      do {
        var content = try fileManager.read(contentsOf: filePath)
        do {
          try chatContextRegistry.context(for: context.threadId).set(knownFileContent: content, for: filePath)
        } catch {
          defaultLogger.error("Failed to register file content for path \(filePath)", error)
        }

        if let lineRange = input.lineRange {
          let lines = content.components(separatedBy: .newlines)
          // -1 as the line is 1-indexed, +1 to make the range inclusive of end line
          let startIndex = lineRange.start - 1
          let endIndex = lineRange.end - 1 + 1
          let selectedLines = lines.safeRange(from: startIndex, to: endIndex)
          content = selectedLines?.joined(separator: "\n") ?? content
        }

        updateStatus.complete(with: .success(Output(content: content, uri: filePath.absoluteString)))
      } catch {
        updateStatus.complete(with: .failure(error))
      }
    }

    public func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
    }

    let filePath: URL

    var mappedInput: Input { resolvedInput }

    @Dependency(\.fileManager) private var fileManager
    @Dependency(\.chatContextRegistry) private var chatContextRegistry

  }

  public let name = "read_file"

  public let description = """
    Description: Request to read the content of a file.
    Parameters:
    - path: (required) The path of the file to read.
    - offset: (optional) Starting line number (0-indexed). Default is 0.
    - limit: (optional) Maximum number of lines to read. If not provided, the tool will attempt to read the entire file.
    """

  public var displayName: String {
    "Read File"
  }

  public var shortDescription: String {
    "Reads the content of a file."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "path": .object([
          "type": .string("string"),
          "description": .string(
            "The file path to read. If the absolute path is known it should be used. Otherwise use a relative path."),
        ]),
        "lineRange": .object([
          "type": .string("object"),
          "description": .string(
            "The range of lines to read (1-based-indexed). For ex: {\"start\": 1, \"finish\": 10} will read the first 10 lines"),
          "properties": .object([
            "start": .object([
              "type": .string("integer"),
              "description": .string("The first line to read (1-based-indexed)."),
            ]),
            "end": .object([
              "type": .string("integer"),
              "description": .string("The last line to read (1-based-indexed). This line is included in the range read."),
            ]),
          ]),
          "required": .array([.string("start"), .string("end")]),
        ]),
      ]),
      "required": .array([.string("path")]),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }
}

// MARK: - ReadFileTool.Use + DisplayableToolUse

extension ReadFileTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    AnyToolUseViewModel(ToolUseViewModel(status: status, input: mappedInput, projectRoot: context.projectRoot))
  }
}

extension [String] {
  /// Safely extracts a range of lines from the array.
  ///
  /// - Parameters:
  ///   - lower: The starting index (inclusive).
  ///   - upper: The ending index (exclusive).
  /// - Returns: An array of strings representing the extracted lines, or nil if the range is invalid.
  /// If the upper bound is negative, it is treated as an offset from the end of the array.
  func safeRange(from lower: Int, to upper: Int) -> [String]? {
    let start = Swift.max(0, lower)
    var end = upper
    if upper < 0 {
      // Never trust an LLM!
      end = self.count + upper + 1
    }
    end = Swift.min(count, end)

    guard start < end else { return nil }
    return Array(self[start..<end])
  }
}
