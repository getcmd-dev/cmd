// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Dependencies
import DLS
import Foundation
import HighlighterServiceInterface
import JSONFoundation
import ToolFoundation

// MARK: - ClaudeCodeReadTool

public final class ClaudeCodeReadTool: NonStreamableTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    init(
      callingTool: ClaudeCodeReadTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = input
      filePath = URL(fileURLWithPath: input.file_path)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .pendingApproval)
      status = stream
      self.updateStatus = updateStatus
    }

    public struct Input: Codable, Sendable {
      public let file_path: String
      public let offset: Int?
      public let limit: Int?
    }

    public struct Output: Codable, Sendable {
      public let content: String
    }

    public let isReadonly = true

    public let callingTool: ClaudeCodeReadTool
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
      // Parse the read file from the text output sent by Claude Code to the server.
      // The ouput is in the format (line number)→... and can contain extra XML like info.

      let parsedOutput = stringOutput
        .split(separator: "\n")
        .compactMap { line in try? /\s*[0-9]+→(.*)/.wholeMatch(in: line)?.output.1 }
        .joined(separator: "\n")
      updateStatus.yield(.completed(.success(.init(content: parsedOutput))))
    }

    public func reject(reason: String?) {
      updateStatus.yield(.approvalRejected(reason: reason))
    }

    public func cancel() {
      updateStatus.yield(.completed(.failure(CancellationError())))
    }

    let filePath: URL

    let context: ToolExecutionContext

    private let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

  }

  public let name = "claude_code_Read"

  public let description = """
    Reads a file from the local filesystem. You can access any file directly by using this tool.\nAssume this tool is able to read all files on the machine. If the User provides a path to a file assume that path is valid. It is okay to read a file that does not exist; an error will be returned.\n\nUsage:\n- The file_path parameter must be an absolute path, not a relative path\n- By default, it reads up to 2000 lines starting from the beginning of the file\n- You can optionally specify a line offset and limit (especially handy for long files), but it's recommended to read the whole file by not providing these parameters\n- Any lines longer than 2000 characters will be truncated\n- Results are returned using cat -n format, with line numbers starting at 1\n- This tool allows Claude Code to read images (eg PNG, JPG, etc). When reading an image file the contents are presented visually as Claude Code is a multimodal LLM.\n- For Jupyter notebooks (.ipynb files), use the NotebookRead instead\n- You have the capability to call multiple tools in a single response. It is always better to speculatively read multiple files as a batch that are potentially useful. \n- You will regularly be asked to read screenshots. If the user provides a path to a screenshot ALWAYS use this tool to view the file at the path. This tool will work with all temporary file paths like /var/folders/123/abc/T/TemporaryItems/NSIRD_screencaptureui_ZfB1tD/Screenshot.png\n- If you read a file that exists but has empty contents you will receive a system reminder warning in place of file contents.
    """

  public var displayName: String {
    "Read (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to read file content, optionally limiting to a specific line range."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "file_path": .object([
          "type": .string("string"),
          "description": .string("The absolute path to the file to read"),
        ]),
        "offset": .object([
          "type": .string("number"),
          "description": .string("The line number to start reading from. Only provide if the file is too large to read at once"),
        ]),
        "limit": .object([
          "type": .string("number"),
          "description": .string("The number of lines to read. Only provide if the file is too large to read at once."),
        ]),
      ]),
      "required": .array([.string("file_path")]),
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

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(status: ClaudeCodeReadTool.Use.Status, input: ClaudeCodeReadTool.Use.Input) {
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
              colors: .codeHighlight)
            self.highlightedContent = highlightedContent
          }
        }
      }
    }
  }

  let input: ClaudeCodeReadTool.Use.Input
  var status: ToolUseExecutionStatus<ClaudeCodeReadTool.Use.Output>
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
