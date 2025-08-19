// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
@testable import ClaudeCodeTools

struct ClaudeCodeWebFetchToolStreamRepresentationTests {
  @MainActor
  @Test("streamRepresentation returns nil when status is not completed")
  func test_streamRepresentationNilWhenNotCompleted() {
    let (status, _) = ClaudeCodeWebFetchTool.Use.Status.makeStream(initial: .running)

    let viewModel = WebFetchToolUseViewModel(
      status: status,
      input: .init(
        url: "https://example.com",
        prompt: "Summarize the content"))

    #expect(viewModel.streamRepresentation == nil)
  }

  @MainActor
  @Test("streamRepresentation shows successful web fetch")
  func test_streamRepresentationSuccessfulFetch() {
    // given
    let testUrl = "https://docs.swift.org/swift-book/"
    let output = ClaudeCodeWebFetchTool.Use.Output(
      result: "Swift Programming Language concepts and examples...")
    let (status, _) = ClaudeCodeWebFetchTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = WebFetchToolUseViewModel(
      status: status,
      input: .init(
        url: testUrl,
        prompt: "Extract key concepts"))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebFetch(\(testUrl))
        ⎿ Content fetched and processed


      """)
  }

  @MainActor
  @Test("streamRepresentation shows failure with error")
  func test_streamRepresentationFailure() {
    // given
    let testUrl = "https://invalid-url-that-does-not-exist.com"
    let error = AppError("URL not found")
    let (status, _) = ClaudeCodeWebFetchTool.Use.Status.makeStream(initial: .completed(.failure(error)))

    let viewModel = WebFetchToolUseViewModel(
      status: status,
      input: .init(
        url: testUrl,
        prompt: "Extract information"))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebFetch(\(testUrl))
        ⎿ Failed: URL not found


      """)
  }

  @MainActor
  @Test("streamRepresentation handles different URL formats")
  func test_streamRepresentationDifferentUrlFormats() {
    let testCases = [
      "https://www.example.com/path/to/page",
      "http://api.service.com/endpoint?param=value",
      "https://subdomain.domain.org/doc.html#section",
    ]

    for testUrl in testCases {
      // given
      let output = ClaudeCodeWebFetchTool.Use.Output(result: "Processed content")
      let (status, _) = ClaudeCodeWebFetchTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = WebFetchToolUseViewModel(
        status: status,
        input: .init(
          url: testUrl,
          prompt: "Process content"))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ WebFetch(\(testUrl))
          ⎿ Content fetched and processed


        """)
    }
  }

  @MainActor
  @Test("streamRepresentation handles network timeout error")
  func test_streamRepresentationNetworkTimeout() {
    // given
    let testUrl = "https://slow-server.example.com"
    let error = AppError("Request timed out")
    let (status, _) = ClaudeCodeWebFetchTool.Use.Status.makeStream(initial: .completed(.failure(error)))

    let viewModel = WebFetchToolUseViewModel(
      status: status,
      input: .init(
        url: testUrl,
        prompt: "Fetch content with timeout"))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebFetch(\(testUrl))
        ⎿ Failed: Request timed out


      """)
  }

  @MainActor
  @Test("streamRepresentation handles complex prompts")
  func test_streamRepresentationComplexPrompt() {
    // given
    let testUrl = "https://research.paper.com/article"
    let complexPrompt = "Extract methodology, results, and conclusions. Focus on quantitative data and statistical significance."
    let output = ClaudeCodeWebFetchTool.Use.Output(
      result: "Detailed analysis of research paper content...")
    let (status, _) = ClaudeCodeWebFetchTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = WebFetchToolUseViewModel(
      status: status,
      input: .init(
        url: testUrl,
        prompt: complexPrompt))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ WebFetch(\(testUrl))
        ⎿ Content fetched and processed


      """)
  }
}
