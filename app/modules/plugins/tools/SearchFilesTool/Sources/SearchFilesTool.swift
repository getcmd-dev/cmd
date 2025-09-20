// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - SearchFilesTool

public final class SearchFilesTool: NonStreamableTool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: NonStreamableToolUse, UpdatableToolUse,
    @unchecked Sendable
  {

    public init(
      callingTool: SearchFilesTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: EmptyObject? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context

      self.input = Input(
        directoryPath: input.directoryPath.resolvePath(from: context.projectRoot).path,
        regex: input.regex,
        filePattern: input.filePattern)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject

    public struct Input: Codable, Sendable {
      public let directoryPath: String
      public let regex: String
      public let filePattern: String?
    }

    public typealias Output = Schema.SearchFilesToolOutput

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let isReadonly = true

    public let callingTool: SearchFilesTool
    public let toolUseId: String
    public let input: Input

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)
      guard let projectRoot = context.projectRoot else {
        updateStatus.complete(with: .failure(AppError("Cannot search files without a project")))
        return
      }

      Task {
        do {
          let fullInput = Schema.SearchFilesToolInput(
            projectRoot: projectRoot.path(),
            directoryPath: input.directoryPath,
            regex: input.regex,
            filePattern: input.filePattern)
          let data = try JSONEncoder.sortingKeys.encode(fullInput)
          let response: Schema.SearchFilesToolOutput = try await server.postRequest(path: "searchFiles", data: data)
          updateStatus.complete(with: .success(Schema.SearchFilesToolOutput(
            outputForLLm: response.outputForLLm,
            results: response.results.map { result in
              Schema.SearchFileResult(
                path: result.path.resolvePath(from: projectRoot).path,
                searchResults: result.searchResults)
            },
            rootPath: response.rootPath,
            hasMore: response.hasMore)))
        } catch {
          updateStatus.complete(with: .failure(error))
        }
      }
    }

    public func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
    }

    @Dependency(\.localServer) private var server

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

}

extension SearchFilesTool.Use.Output {
  // TODO: deal with this properly, to allow for serialization for message history.
  /// Only encode the output for LLM
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(outputForLLm)
  }
}

// MARK: - SearchFilesTool.Use + DisplayableToolUse

extension SearchFilesTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(ToolUseViewModel(status: status, input: input))
  }
}
