// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
import ToolTypesFoundation
@testable import SearchFilesTool

struct SearchFilesToolStreamRepresentationTests {
  @MainActor
  @Test("streamRepresentation returns nil when status is not completed")
  func test_streamRepresentationNilWhenNotCompleted() {
    let input = ToolsSchema.SearchFilesToolInput(directoryPath: "/test", regex: "pattern", filePattern: nil)
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .running(input: input))

    let viewModel = ToolUseViewModel(
      status: status,
      input: input,
      rootPath: "/")

    #expect(viewModel.streamRepresentation == nil)
  }

  @MainActor
  @Test("streamRepresentation shows success with match count")
  func test_streamRepresentationSuccess() {
    // given
    let input = ToolsSchema.SearchFilesToolInput(directoryPath: "/test", regex: "pattern", filePattern: nil)
    let output = ToolsSchema.SearchFilesToolOutput(
      outputForLLm: "Search results",
      results: [
        .init(path: "/test/file1.txt", searchResults: [
          .init(line: 1, text: "pattern match", isMatch: true),
        ]),
        .init(path: "/test/file2.txt", searchResults: [
          .init(line: 5, text: "another pattern", isMatch: true),
        ]),
      ],
      hasMore: false)
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .completed(input: input, result: .success(output)))

    let viewModel = ToolUseViewModel(
      status: status,
      input: input,
      rootPath: "/test")

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Search(pattern)
        ⎿ Found 2 matches


      """)
  }

  @MainActor
  @Test("streamRepresentation shows success with truncated results")
  func test_streamRepresentationSuccessWithTruncation() {
    // given
    let input = ToolsSchema.SearchFilesToolInput(directoryPath: "/test", regex: "test.*pattern", filePattern: "*.swift")
    let output = ToolsSchema.SearchFilesToolOutput(
      outputForLLm: "Search results",
      results: [
        .init(path: "/test/file1.swift", searchResults: [
          .init(line: 1, text: "test pattern", isMatch: true),
        ]),
      ],
      hasMore: true)
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .completed(input: input, result: .success(output)))

    let viewModel = ToolUseViewModel(
      status: status,
      input: input,
      rootPath: "/test")

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Search(test.*pattern)
        ⎿ Found 1 matches (truncated)


      """)
  }

  @MainActor
  @Test("streamRepresentation shows failure with error")
  func test_streamRepresentationFailure() {
    // given
    let input = ToolsSchema.SearchFilesToolInput(directoryPath: "/test", regex: "pattern", filePattern: nil)
    let error = AppError("Directory not found")
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .completed(input: input, result: .failure(error)))

    let viewModel = ToolUseViewModel(
      status: status,
      input: input,
      rootPath: "/test")

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Search(pattern)
        ⎿ Failed: Directory not found


      """)
  }

  @MainActor
  @Test("streamRepresentation handles empty results")
  func test_streamRepresentationEmptyResults() {
    // given
    let input = ToolsSchema.SearchFilesToolInput(directoryPath: "/test", regex: "nonexistent", filePattern: nil)
    let output = ToolsSchema.SearchFilesToolOutput(
      outputForLLm: "No results",
      results: [],
      hasMore: false)
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .completed(input: input, result: .success(output)))

    let viewModel = ToolUseViewModel(
      status: status,
      input: input,
      rootPath: "/test")

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Search(nonexistent)
        ⎿ Found 0 matches


      """)
  }
}
