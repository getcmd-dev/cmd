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
import ToolTypesFoundation

// MARK: - SearchFilesTool

public final class SearchFilesTool: Tool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse,
    @unchecked Sendable
  {

    public init(
      callingTool: SearchFilesTool,
      toolUseId: String,
      inputResult: Result<Input, ToolDecodingError>,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context

      // Extract input or create fallback
      let input: Input =
        switch inputResult {
        case .success(let value):
          value
        case .failure:
          // Fallback for failed decoding
          Input(directoryPath: nil, regex: "", filePattern: nil)
        }

      resolvedInput = Input(
        directoryPath: input.directoryPath.map { $0.resolvePath(from: context.projectRoot).path },
        regex: input.regex,
        filePattern: input.filePattern)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus?.completedOrCancelled ?? .notStarted(input: resolvedInput))
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias Input = ToolsSchema.SearchFilesToolInput

    public typealias Output = ToolsSchema.SearchFilesToolOutput

    public typealias InternalState = RootPath
    public struct RootPath: Codable, Sendable {
      let rootPath: String?

      init(rootPath: String?) {
        self.rootPath = rootPath
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Only encode rootPath if it's not nil
        if let rootPath {
          try container.encode(rootPath, forKey: .rootPath)
        }
      }

      private enum CodingKeys: String, CodingKey {
        case rootPath
      }
    }

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let isReadonly = true

    public let callingTool: SearchFilesTool
    public let toolUseId: String
    public let resolvedInput: Input

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Input, Output>>.Continuation

    public var internalState: InternalState? {
      RootPath(rootPath: context.projectRoot?.path())
    }

    public func startExecuting() {
      guard let input = status.value.input else { return }

      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted(input: input))
      updateStatus.yield(.running(input: input))
      guard let projectRoot = context.projectRoot else {
        updateStatus.complete(with: .failure(AppError("Cannot search files without a project")), input: input)
        return
      }

      Task {
        do {
          let fullInput = Schema.SearchFilesRequestInput(
            projectRoot: projectRoot.path(),
            directoryPath: resolvedInput.directoryPath ?? projectRoot.path,
            regex: resolvedInput.regex,
            filePattern: resolvedInput.filePattern)
          let data = try JSONEncoder.sortingKeys.encode(fullInput)
          let response: ToolsSchema.SearchFilesToolOutput = try await server.postRequest(path: "searchFiles", data: data)
          updateStatus.complete(with: .success(ToolsSchema.SearchFilesToolOutput(
            outputForLLm: response.outputForLLm,
            results: response.results.map { result in
              ToolsSchema.SearchFileResult(
                path: result.path.resolvePath(from: projectRoot).path,
                searchResults: result.searchResults)
            },
            hasMore: response.hasMore)), input: input)
        } catch {
          updateStatus.complete(with: .failure(error), input: input)
        }
      }
    }

    public func receive(output: JSONFoundation.JSON.Value) throws {
      guard let input = status.value.input else { return }
      let output = try JSONDecoder().decode(Output.self, from: JSONEncoder().encode(output))
      updateStatus.complete(with: .success(output), input: input)
    }

    public func cancel() {
      guard let input = status.value.input else { return }
      updateStatus.complete(with: .failure(CancellationError()), input: input)
    }

    @Dependency(\.localServer) private var server

  }

  public let id = "search"
  public let name = "search_files"

  public let description = """
    Request to perform a regex search across files in a specified directory, providing context-rich results. This tool searches for patterns or specific content across multiple files, displaying each match with encapsulating context.
    """

  public var referenceId: String { id }

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
    AnyToolUseViewModel(ToolUseViewModel(status: status, input: resolvedInput, rootPath: context.projectRoot?.path))
  }
}
