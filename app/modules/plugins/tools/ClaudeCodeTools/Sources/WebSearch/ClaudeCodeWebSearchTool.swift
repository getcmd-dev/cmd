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
import ToolFoundation

// MARK: - ClaudeCodeWebSearchTool

public final class ClaudeCodeWebSearchTool: ExternalTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    public init(
      callingTool: ClaudeCodeWebSearchTool,
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

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject
    public struct Input: Codable, Sendable {
      public let query: String
      public let allowed_domains: [String]?
      public let blocked_domains: [String]?
    }

    public struct Output: Codable, Sendable {
      public struct SearchResult: Codable, Sendable {
        public let title: String
        public let url: String
      }

      public let links: [SearchResult]
      public let content: String
    }

    public let isReadonly = true

    public let callingTool: ClaudeCodeWebSearchTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func receive(output: String) throws {
      // Parse the output from Claude Code
      let parsedOutput = try parseWebSearchOutput(output)
      updateStatus.complete(with: .success(parsedOutput))
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

  public func isAvailable(in _: ChatMode) -> Bool {
    true
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
      for await status in status {
        self?.status = status
      }
    }
  }

  let input: ClaudeCodeWebSearchTool.Use.Input
  var status: ToolUseExecutionStatus<ClaudeCodeWebSearchTool.Use.Output>
}

// MARK: - ToolError

struct ToolError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}
