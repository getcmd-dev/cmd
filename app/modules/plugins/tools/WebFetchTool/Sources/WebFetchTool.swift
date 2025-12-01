// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import LLMServiceInterface
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
      input: Input,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = input
      @Dependency(\.llmService) var llmService
      self.llmService = llmService

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus?.completedOrCancelled ?? .notStarted)
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
    public let input: Input

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func startExecuting() {
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)

      guard let model = llmService.lowTierModel()?.modelInfo ?? llmService.activeModels.value.first else {
        updateStatus.complete(with: .failure(AppError("No available LLM models to process the web content.")))
        return
      }

      Task { @MainActor in
        do {
          // Fetch the web content
          let markdown = try await WebContentFetcher.fetchContentAsync(from: input.url)

          guard
            let summary = try await llmService.prompt("""
              Here's the markdown rendering of the webpath fetched from \(input.url):
              <markdown>
              \(markdown)
              </markdown>

              Now, please respond to the following prompt:
              \(input.prompt)

              Provide a concise response based only on the content above. In your response:
               - Enforce a strict 125-character maximum for quotes from any source document. Open Source Software is ok as long as we respect the license.
               - Use quotation marks for exact language from articles; any language outside of the quotation should never be word-for-word the same.
               - You are not a lawyer and never comment on the legality of your own prompts and responses.
               - Never produce or reproduce exact song lyrics.
              """, model: model)
          else {
            updateStatus.complete(with: .failure(AppError("Failed to summarize the web content.")))
            return
          }
          let output = Output(result: summary)

          updateStatus.complete(with: .success(output))
        } catch {
          updateStatus.complete(with: .failure(error))
        }
      }
    }

    public func receive(output: JSONFoundation.JSON.Value) throws {
      let output = try JSONDecoder().decode(Output.self, from: JSONEncoder().encode(output))
      updateStatus.complete(with: .success(output))
    }

    public func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
    }

    private let llmService: LLMService

  }

  public let id = "web_fetch"
  public let name = "web_fetch"

  public let description = """
    "
    - Fetches content from a specified URL and processes it using an AI model
    - Takes a URL and a prompt as input
    - Fetches the URL content, converts HTML to markdown
    - Processes the content with the prompt using a small, fast model
    - Returns the model's response about the content
    - Use this tool when you need to retrieve and analyze web content

    Usage notes:
      - IMPORTANT: If an MCP-provided web fetch tool is available, prefer using that tool instead of this one, as it may have fewer restrictions. All MCP-provided tools start with \"mcp__\".
      - The URL must be a fully-formed valid URL
      - HTTP URLs will be automatically upgraded to HTTPS
      - The prompt should describe what information you want to extract from the page
      - This tool is read-only and does not modify any files
      - Results may be summarized if the content is very large
      - Includes a self-cleaning 15-minute cache for faster responses when repeatedly accessing the same URL
      - When a URL redirects to a different host, the tool will inform you and provide the redirect URL in a special format. You should then make a new WebFetch request with the redirect URL to fetch the content.
    "
    """

  public let inputSchema: JSON =
    try! JSONDecoder().decode(JSON.self, from: """
      {
          "type": "object",
          "properties": {
            "url": {
              "type": "string",
              "format": "uri",
              "description": "The URL to fetch content from"
            },
            "prompt": {
              "type": "string",
              "description": "The prompt to run on the fetched content"
            }
          },
          "required": [
            "url",
            "prompt"
          ],
          "additionalProperties": false,
          "$schema": "http://json-schema.org/draft-07/schema#"
        }
      """.utf8Data)

  public var referenceId: String { id }

  public var displayName: String {
    "WebFetch"
  }

  public var shortDescription: String {
    "Fetch and analyze web content using an AI model."
  }

}

// MARK: - WebFetchTool.Use + DisplayableToolUse

extension WebFetchTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(WebFetchToolUseViewModel(
      status: status,
      input: input))
  }
}
