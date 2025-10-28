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

// MARK: - WebFetchTool

public final class WebFetchTool: Tool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse,
    @unchecked Sendable
  {
    public init(
      callingTool: WebFetchTool,
      toolUseId: String,
      inputResult: Result<Input, ToolDecodingError>,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context

      let input: Input =
        switch inputResult {
        case .success(let value):
          value
        case .failure:
          Input(url: "", prompt: "")
        }

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted(input: input))
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias Input = ToolsSchema.WebFetchToolInput
    public typealias Output = ToolsSchema.WebFetchToolOutput

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let isReadonly = true

    public let callingTool: WebFetchTool
    public let toolUseId: String

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Input, Output>>.Continuation

    public var input: Input? { status.value.input }

    public func startExecuting() {
      guard let input = status.value.input else { return }
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

  public let id = "web_fetch"
  public let name = "web_fetch"

  public let description = """
    Fetches content from a specified URL and processes it using an AI model. Takes a URL and a prompt as input, fetches the URL content, converts HTML to markdown, and processes the content with the prompt using a small, fast model. Returns the model's response about the content.
    """

  public var referenceId: String { id }

  public var displayName: String {
    "WebFetch"
  }

  public var shortDescription: String {
    "Fetch and analyze web content using an AI model."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "url": .object([
          "type": .string("string"),
          "format": .string("uri"),
          "description": .string("The URL to fetch content from"),
        ]),
        "prompt": .object([
          "type": .string("string"),
          "description": .string("The prompt to run on the fetched content"),
        ]),
      ]),
      "required": .array([.string("url"), .string("prompt")]),
    ])
  }

}

// MARK: - WebFetchTool.Use + DisplayableToolUse

extension WebFetchTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(WebFetchToolUseViewModel(
      status: status,
      input: input ?? Input(url: "", prompt: "")))
  }
}
