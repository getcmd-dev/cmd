// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
@testable import ClaudeCodeTools

struct ClaudeCodeWebSearchToolStreamRepresentationTests {
  @MainActor
  @Test("streamRepresentation returns nil when status is not completed")
  func test_streamRepresentationNilWhenNotCompleted() {
    let (status, _) = ClaudeCodeWebSearchTool.Use.Status.makeStream(initial: .running)

    let viewModel = WebSearchToolUseViewModel(
      status: status,
      input: .init(query: "Swift programming", allowed_domains: nil, blocked_domains: nil))

    #expect(viewModel.streamRepresentation == nil)
  }

  @MainActor
  @Test("streamRepresentation shows successful web search with results")
  func test_streamRepresentationSuccessWithResults() {
    // given
    let output = ClaudeCodeWebSearchTool.Use.Output(
      links: [
        .init(title: "SwiftUI Guide", url: "https://example.com/guide"),
        .init(title: "Best Practices", url: "https://example.com/practices"),
        .init(title: "Advanced SwiftUI", url: "https://example.com/advanced"),
      ],
      content: "Search results for SwiftUI")
    let (status, _) = ClaudeCodeWebSearchTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = WebSearchToolUseViewModel(
      status: status,
      input: .init(query: "SwiftUI best practices", allowed_domains: nil, blocked_domains: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebSearch(SwiftUI best practices)
        ⎿ Found 3 results


      """)
  }

  @MainActor
  @Test("streamRepresentation shows successful web search with no results")
  func test_streamRepresentationSuccessNoResults() {
    // given
    let output = ClaudeCodeWebSearchTool.Use.Output(
      links: [],
      content: "No results found")
    let (status, _) = ClaudeCodeWebSearchTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = WebSearchToolUseViewModel(
      status: status,
      input: .init(query: "very specific obscure query", allowed_domains: nil, blocked_domains: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebSearch(very specific obscure query)
        ⎿ Found 0 results


      """)
  }

  @MainActor
  @Test("streamRepresentation shows failure with error")
  func test_streamRepresentationFailure() {
    // given
    let error = AppError("Network connection failed")
    let (status, _) = ClaudeCodeWebSearchTool.Use.Status.makeStream(initial: .completed(.failure(error)))

    let viewModel = WebSearchToolUseViewModel(
      status: status,
      input: .init(query: "network error test", allowed_domains: nil, blocked_domains: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebSearch(network error test)
        ⎿ Failed: Network connection failed


      """)
  }

  @MainActor
  @Test("streamRepresentation handles single result")
  func test_streamRepresentationSingleResult() {
    // given
    let output = ClaudeCodeWebSearchTool.Use.Output(
      links: [
        .init(title: "Official Docs", url: "https://docs.example.com"),
      ],
      content: "Found specific page")
    let (status, _) = ClaudeCodeWebSearchTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = WebSearchToolUseViewModel(
      status: status,
      input: .init(query: "specific documentation page", allowed_domains: nil, blocked_domains: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebSearch(specific documentation page)
        ⎿ Found 1 results


      """)
  }

  @MainActor
  @Test("streamRepresentation handles complex query with special characters")
  func test_streamRepresentationComplexQuery() {
    // given
    let complexQuery = "\"Swift async/await\" AND (concurrency OR threading) -tutorial"
    let output = ClaudeCodeWebSearchTool.Use.Output(
      links: [
        .init(title: "Concurrency Guide", url: "https://example.com/concurrency"),
        .init(title: "Threading Best Practices", url: "https://example.com/threading"),
      ],
      content: "Advanced search results")
    let (status, _) = ClaudeCodeWebSearchTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = WebSearchToolUseViewModel(
      status: status,
      input: .init(query: complexQuery, allowed_domains: nil, blocked_domains: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebSearch(\(complexQuery))
        ⎿ Found 2 results


      """)
  }
}
