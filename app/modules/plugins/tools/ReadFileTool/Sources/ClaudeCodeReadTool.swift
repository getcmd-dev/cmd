// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatServiceInterface
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import Foundation
import FoundationInterfaces
import HighlighterServiceInterface
import JSONFoundation
import LoggingServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeReadTool

public final class ClaudeCodeReadTool: ExternalTool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ExternalToolUse, @unchecked Sendable {
    public init(
      callingTool: ClaudeCodeReadTool,
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
      filePath = URL(fileURLWithPath: input.file_path)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject
    public struct Input: Codable, Sendable {
      public let file_path: String
      public let offset: Int?
      public let limit: Int?
    }

    public typealias Output = ReadFileTool.Use.Output

    public let isReadonly = true

    public let callingTool: ClaudeCodeReadTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func receive(output: JSON.Value) throws {
      let data = try JSONEncoder().encode(output)
      let output = try JSONDecoder().decode(ClaudeCodeOutput.self, from: data)
      updateStatus.complete(with: .success(.init(content: output.content, uri: input.file_path)))

      guard output.isText else { return }

      // Sync current file content to help manage edits.
      do {
        let content = try fileManager.read(contentsOf: filePath)
        try chatContextRegistry.context(for: context.threadId).set(knownFileContent: content, for: filePath)
      } catch {
        defaultLogger.error("Failed to register file content for path \(filePath)", error)
      }
    }

    enum ClaudeCodeOutput: Decodable {
      case files(_ files: [File])
      case rawText(_ text: String)

      init(from decoder: any Decoder) throws {
        do {
          let content = try String(from: decoder)
          // Parse the read file from the text output sent by Claude Code to the server.
          // The ouput is in the format (line number)→... and can contain extra XML like info.
          let parsedContent = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line in try? /\s*[0-9]+→(.*)/.wholeMatch(in: line)?.output.1 }
            .joined(separator: "\n")
          self = .rawText(parsedContent)
        } catch {
          self = try .files([File](from: decoder))
        }
      }

      struct File: Decodable {
        let type: String
        let source: ImageSource

        struct ImageSource: Decodable {
          let media_type: String
          let type: String
          let data: String
        }
      }

      var content: String {
        switch self {
        case .rawText(let text): text
        case .files(let files): files.map { "<file media_type=\"\($0.source.media_type)\">" }.joined(separator: "\n")
        }
      }

      var isText: Bool {
        if case .rawText = self { return true }
        return false
      }
    }

    let filePath: URL

    @Dependency(\.fileManager) private var fileManager
    @Dependency(\.chatContextRegistry) private var chatContextRegistry

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

}

// MARK: - ClaudeCodeReadTool.Use + DisplayableToolUse

extension ClaudeCodeReadTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    let lineRange: ReadFileTool.Use.Input.Range? = {
      if let limit = input.limit {
        if let offset = input.offset {
          return .init(start: offset, end: offset + limit)
        } else {
          return .init(start: 0, end: limit)
        }
      }
      if let offset = input.offset {
        return .init(start: offset, end: Int.max)
      }
      return nil
    }()

    return AnyToolUseViewModel(ToolUseViewModel(
      status: status, input: .init(path: input.file_path, lineRange: lineRange), projectRoot: context.projectRoot))
  }
}
