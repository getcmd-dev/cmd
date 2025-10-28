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

// MARK: - WebSearchTool

public final class WebSearchTool: Tool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse,
    @unchecked Sendable
  {
    public init(
      callingTool: WebSearchTool,
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
          Input(query: "")
        }

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted(input: input))
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias Input = ToolsSchema.WebSearchToolInput
    public typealias Output = ToolsSchema.WebSearchToolOutput

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let isReadonly = true

    public let callingTool: WebSearchTool
    public let toolUseId: String

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Input, Output>>.Continuation

    public func startExecuting() {
      guard let input = status.value.input else { return }
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted(input: input))
      updateStatus.yield(.running(input: input))
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

  }

  public let canBeExecuted = false

  public let id = "web_search"
  public let name = "web_search"

  public let description = """
    Allows Claude to search the web and use the results to inform responses. Provides up-to-date information for current events and recent data. Returns search result information formatted as search result blocks. Use this tool for accessing information beyond Claude's knowledge cutoff.
    """

  public var referenceId: String { id }

  public var displayName: String {
    "WebSearch"
  }

  public var shortDescription: String {
    "Search the web and return search results with content."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "query": .object([
          "type": .string("string"),
          "minLength": .number(2),
          "description": .string("The search query to use"),
        ]),
        "allowed_domains": .object([
          "type": .string("array"),
          "items": .object([
            "type": .string("string"),
          ]),
          "description": .string("Only include search results from these domains"),
        ]),
        "blocked_domains": .object([
          "type": .string("array"),
          "items": .object([
            "type": .string("string"),
          ]),
          "description": .string("Never include search results from these domains"),
        ]),
      ]),
      "required": .array([.string("query")]),
    ])
  }

}

// MARK: - WebSearchTool.Use + DisplayableToolUse

extension WebSearchTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(WebSearchToolUseViewModel(
      status: status,
      input: (try? input) ?? Input(query: "")))
  }
}

extension ToolsSchema.WebSearchToolOutput {
  typealias SearchResult = ToolsSchema.WebSearchToolOutput_SearchResult
}
