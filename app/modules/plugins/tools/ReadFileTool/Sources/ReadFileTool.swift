// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Dependencies
import DLS
import Foundation
import FoundationInterfaces
import HighlighterServiceInterface
import JSONFoundation
import ToolFoundation

// MARK: - ReadFileTool

public final class ReadFileTool: NonStreamableTool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse, @unchecked Sendable {
    init(
      callingTool: ReadFileTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = Input(
        path: input.path.resolvePath(from: context.projectRoot).path(),
        lineRange: input.lineRange)
      filePath = URL(fileURLWithPath: self.input.path)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .pendingApproval)
      status = stream
      self.updateStatus = updateStatus
    }

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

    public let isReadonly = true

    public let callingTool: ReadFileTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)

      do {
        var content = try fileManager.read(contentsOf: filePath)
        if let lineRange = input.lineRange {
          let lines = content.components(separatedBy: .newlines)
          let selectedLines = lines[safe: (lineRange.start - 1)..<(lineRange.end)]
          content = selectedLines?.joined(separator: "\n") ?? content
        }

        updateStatus.yield(.completed(.success(Output(content: content, uri: filePath.absoluteString))))
      } catch {
        updateStatus.yield(.completed(.failure(error)))
      }
    }

    public func reject(reason: String?) {
      updateStatus.yield(.approvalRejected(reason: reason))
    }

    public func cancel() {
      updateStatus.yield(.completed(.failure(CancellationError())))
    }

    let filePath: URL

    let context: ToolExecutionContext

    @Dependency(\.server) private var server
    @Dependency(\.fileManager) private var fileManager

    private let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

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
    "Reads the content of a file, optionally limiting to a specific line range."
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

  public func use(toolUseId: String, input: Use.Input, context: ToolExecutionContext) -> Use {
    Use(callingTool: self, toolUseId: toolUseId, input: input, context: context)
  }

}

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(status: ReadFileTool.Use.Status, input: ReadFileTool.Use.Input) {
    self.status = status.value
    self.input = input
    Task { [weak self] in
      for await status in status {
        self?.status = status
        if case .completed(.success(let output)) = status {
          Task {
            guard let self else { return }
            let highlightedContent = try await self.highlighter.attributedText(
              output.content,
              language: FileIcon.language(for: URL(fileURLWithPath: output.uri)),
              colors: .codeHighlight)
            self.highlightedContent = highlightedContent
          }
        }
      }
    }
  }

  let input: ReadFileTool.Use.Input
  var status: ToolUseExecutionStatus<ReadFileTool.Use.Output>
  var highlightedContent: AttributedString?

  @ObservationIgnored
  @Dependency(\.highlighter) private var highlighter
}

extension [String] {
  subscript(safe range: Range<Int>) -> [String]? {
    let start = Swift.max(0, range.lowerBound)
    let end = Swift.min(count, range.upperBound)

    guard start < end else { return nil }
    return Array(self[start..<end])
  }
}
