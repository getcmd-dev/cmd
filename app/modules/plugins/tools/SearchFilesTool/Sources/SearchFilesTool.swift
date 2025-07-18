// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import ServerServiceInterface
import ToolFoundation

// MARK: - SearchFilesTool

public final class SearchFilesTool: NonStreamableTool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse, @unchecked Sendable {

    init(
      callingTool: SearchFilesTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context

      self.input = Input(
        directoryPath: input.directoryPath.resolvePath(from: context.projectRoot).path,
        regex: input.regex,
        filePattern: input.filePattern)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .pendingApproval)
      status = stream
      self.updateStatus = updateStatus
    }

    public struct Input: Codable, Sendable {
      public let directoryPath: String
      public let regex: String
      public let filePattern: String?
    }

    public typealias Output = Schema.SearchFilesToolOutput

    public let isReadonly = true

    public let callingTool: SearchFilesTool
    public let toolUseId: String
    public let input: Input

    public let status: Status

    public func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)
      guard let projectRoot = context.projectRoot else {
        updateStatus.yield(.completed(.failure(AppError("Cannot search files without a project"))))
        return
      }

      Task {
        do {
          let fullInput = Schema.SearchFilesToolInput(
            projectRoot: projectRoot.path(),
            directoryPath: input.directoryPath,
            regex: input.regex,
            filePattern: input.filePattern)
          let data = try JSONEncoder().encode(fullInput)
          let response: Schema.SearchFilesToolOutput = try await server.postRequest(path: "searchFiles", data: data)
          updateStatus.yield(.completed(.success(Schema.SearchFilesToolOutput(
            outputForLLm: response.outputForLLm,
            results: response.results.map { result in
              Schema.SearchFileResult(
                path: result.path.resolvePath(from: projectRoot).path,
                searchResults: result.searchResults)
            },
            rootPath: response.rootPath,
            hasMore: response.hasMore))))
        } catch {
          updateStatus.yield(.completed(.failure(error)))
        }
      }
    }

    public func reject(reason: String?) {
      updateStatus.yield(.approvalRejected(reason: reason))
    }

    public func cancel() {
      updateStatus.yield(.completed(.failure(CancellationError())))
    }

    let context: ToolExecutionContext

    @Dependency(\.server) private var server

    private let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

  }

  public let name = "search_files"

  public let description = """
    Request to perform a regex search across files in a specified directory, providing context-rich results. This tool searches for patterns or specific content across multiple files, displaying each match with encapsulating context.
    """

  public var displayName: String {
    "Search Files"
  }

  public var shortDescription: String {
    "Performs regex search across files in a directory, returning matches with context."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "directoryPath": .object([
          "type": .string("string"),
          "description": .string(
            "The path of the directory to search in (relative to the current working directory ${args.cwd}). This directory will be recursively searched."),
        ]),
        "regex": .object([
          "type": .string("string"),
          "description": .string("The regular expression pattern to search for. Uses Rust regex syntax."),
        ]),
        "filePattern": .object([
          "type": .string("string"),
          "description": .string(
            "Glob pattern to filter files (e.g., '*.ts' for TypeScript files). If not provided, it will search all files (*)"),
        ]),
      ]),
      "required": .array([.string("directoryPath"), .string("regex")]),
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

  init(
    status: SearchFilesTool.Use.Status,
    input: SearchFilesTool.Use.Input)
  {
    self.status = status.value
    self.input = input
    Task {
      for await status in status {
        self.status = status
      }
    }
  }

  let input: SearchFilesTool.Use.Input
  var status: ToolUseExecutionStatus<SearchFilesTool.Use.Output>
}

extension SearchFilesTool.Use.Output {
  // TODO: deal with this properly, to allow for serialization for message history.
  /// Only encode the output for LLM
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(outputForLLm)
  }
}
