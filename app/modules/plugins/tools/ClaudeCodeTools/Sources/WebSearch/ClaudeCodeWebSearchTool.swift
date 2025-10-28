// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import Foundation
import JSONFoundation
import JSONScanner
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeWebSearchTool

public final class ClaudeCodeWebSearchTool: Tool {

  public init() { }

  public final class Use: ToolUse, @unchecked Sendable {
    public init(
      callingTool: ClaudeCodeWebSearchTool,
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
          Input(query: "", allowedDomains: nil, blockedDomains: nil)
        }

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus?.completedOrCancelled ?? .notStarted(input: input))
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject
    public typealias Input = WebSearchTool.Use.Input
    public typealias Output = WebSearchTool.Use.Output

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let isReadonly = true

    public let callingTool: ClaudeCodeWebSearchTool
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
      // Parse the output from Claude Code
      let parsedOutput = try parseWebSearchOutput(output)
      updateStatus.complete(with: .success(parsedOutput), input: input)
    }

    /// Parses the output from Claude Code's web search tool.
    /// The output appears to be formatted like:
    ///
    /// Web search results for query: ...
    ///
    /// ...
    ///
    /// Links: [{"title":"...","url":"..."}, ...]
    ///
    /// ...
    private func parseWebSearchOutput(_ output: String) throws -> Output {
      do {
        // Find the Links: section
        guard
          let payloadStart = output.range(of: "Links: [").map({ output.index(before: $0.upperBound) }),
          let data = output[payloadStart...].data(using: .utf8)
        else {
          throw ToolError("Could not find Links section in output")
        }
        let endIndex = try data.withUnsafeBytes { bytes in
          var scanner = JSONScanner(source: bytes, options: .init())
          try scanner.skipValue()
          return scanner.index
        }
        let searchResults = try JSONDecoder().decode([Output.SearchResult].self, from: data[..<endIndex])

        // Extract the content after the links section
        let content = String(data: data[endIndex...], encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return Output(links: searchResults, content: content)
      } catch {
        throw ToolError("Could not find Links section in output")
      }
    }

  }

  public let id = "claude_code_web_search"
  public let referenceId = "web_search"

  public let name = "claude_code_WebSearch"

  public let description = """
    - Allows Claude to search the web and use the results to inform responses
    - Provides up-to-date information for current events and recent data
    - Returns search result information formatted as search result blocks
    - Use this tool for accessing information beyond Claude's knowledge cutoff
    - Searches are performed automatically within a single API call

    Usage notes:
      - Domain filtering is supported to include or block specific websites
      - Web search is only available in the US
      - Account for "Today's date" in <env>. For example, if <env> says "Today's date: 2025-07-01", and the user wants the latest docs, do not use 2024 in the search query. Use 2025.
    """

  public var displayName: String {
    "WebSearch (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to search the web and return search results with content."
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
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

}

// MARK: - WebSearchToolUseViewModel

@Observable
@MainActor
final class WebSearchToolUseViewModel {

  init(status: ClaudeCodeWebSearchTool.Use.Status, input: ClaudeCodeWebSearchTool.Use.Input) {
    self.status = status.value
    self.input = input
    Task { [weak self] in
      for await status in status.futureUpdates {
        self?.status = status
      }
    }
  }

  let input: ClaudeCodeWebSearchTool.Use.Input
  var status: ToolUseExecutionStatus<ClaudeCodeWebSearchTool.Use.Input, ClaudeCodeWebSearchTool.Use.Output>
}

// MARK: ViewRepresentable, StreamRepresentable

extension WebSearchToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(WebSearchToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(_, let result) = status else { return nil }
    switch result {
    case .success(let output):
      return """
        ⏺ WebSearch(\(input.query))
          ⎿ Found \(output.links.count) results


        """

    case .failure(let error):
      return """
        ⏺ WebSearch(\(input.query))
          ⎿ Failed: \(error.localizedDescription)


        """
    }
  }
}

// MARK: - ToolError

struct ToolError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}
