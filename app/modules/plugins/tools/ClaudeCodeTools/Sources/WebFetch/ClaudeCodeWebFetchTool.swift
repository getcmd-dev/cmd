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

// MARK: - ClaudeCodeWebFetchTool

public final class ClaudeCodeWebFetchTool: Tool {

  public init() { }

  public final class Use: ToolUse, @unchecked Sendable {
    public init(
      callingTool: ClaudeCodeWebFetchTool,
      toolUseId: String,
      inputResult: Result<Input, ToolDecodingError>,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context

      let input: Input
      switch inputResult {
      case .success(let value):
        input = value
      case .failure:
        input = Input(url: "", prompt: "")
      }

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted(input: input))
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject

    public typealias Input = WebFetchTool.Use.Input
    public typealias Output = WebFetchTool.Use.Output

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let isReadonly = true

    public let callingTool: ClaudeCodeWebFetchTool
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

    public func receive(output: JSON.Value) throws {
      guard let input = status.value.input else { return }
      let output = try requireStringOutput(from: output)
      // The output from Claude Code is the result of applying the prompt to the fetched content
      updateStatus.complete(with: .success(.init(result: output)), input: input)
    }

  }

  public let id = "claude_code_web_fetch"
  public let referenceId = "web_fetch"

  public let name = "claude_code_WebFetch"

  public let description = """
    - Fetches content from a specified URL and processes it using an AI model
    - Takes a URL and a prompt as input
    - Fetches the URL content, converts HTML to markdown
    - Processes the content with the prompt using a small, fast model
    - Returns the model's response about the content
    - Use this tool when you need to retrieve and analyze web content

    Usage notes:
      - IMPORTANT: If an MCP-provided web fetch tool is available, prefer using that tool instead of this one, as it may have fewer restrictions. All MCP-provided tools start with "mcp__".
      - The URL must be a fully-formed valid URL
      - HTTP URLs will be automatically upgraded to HTTPS
      - The prompt should describe what information you want to extract from the page
      - This tool is read-only and does not modify any files
      - Results may be summarized if the content is very large
      - Includes a self-cleaning 15-minute cache for faster responses when repeatedly accessing the same URL
      - When a URL redirects to a different host, the tool will inform you and provide the redirect URL in a special format. You should then make a new WebFetch request with the redirect URL to fetch the content.
    """

  public var displayName: String {
    "WebFetch (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to fetch and analyze web content using an AI model."
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
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

}

// MARK: - WebFetchToolUseViewModel

@Observable
@MainActor
final class WebFetchToolUseViewModel {

  init(status: ClaudeCodeWebFetchTool.Use.Status, input: ClaudeCodeWebFetchTool.Use.Input) {
    self.status = status.value
    self.input = input
    Task { [weak self] in
      for await status in status.futureUpdates {
        self?.status = status
      }
    }
  }

  let input: ClaudeCodeWebFetchTool.Use.Input
  var status: ToolUseExecutionStatus<ClaudeCodeWebFetchTool.Use.Input, ClaudeCodeWebFetchTool.Use.Output>
}

// MARK: ViewRepresentable, StreamRepresentable

extension WebFetchToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(WebFetchToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(_, let result) = status else { return nil }
    switch result {
    case .success:
      return """
        ⏺ WebFetch(\(input.url))
          ⎿ Content fetched and processed


        """

    case .failure(let error):
      return """
        ⏺ WebFetch(\(input.url))
          ⎿ Failed: \(error.localizedDescription)


        """
    }
  }
}
