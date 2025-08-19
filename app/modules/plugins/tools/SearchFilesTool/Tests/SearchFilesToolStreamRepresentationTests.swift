// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import LocalServerServiceInterface
import SwiftTesting
import Testing
@testable import SearchFilesTool

struct SearchFilesToolStreamRepresentationTests {
  @MainActor
  @Test("streamRepresentation returns nil when status is not completed")
  func test_streamRepresentationNilWhenNotCompleted() {
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .running)

    let viewModel = ToolUseViewModel(
      status: status,
      input: .init(directoryPath: "/test", regex: "pattern", filePattern: nil))

    #expect(viewModel.streamRepresentation == nil)
  }

  @MainActor
  @Test("streamRepresentation shows success with match count")
  func test_streamRepresentationSuccess() {
    // given
    let output = Schema.SearchFilesToolOutput(
      outputForLLm: "Search results",
      results: [
        .init(path: "/test/file1.txt", searchResults: [
          .init(line: 1, text: "pattern match", isMatch: true),
        ]),
        .init(path: "/test/file2.txt", searchResults: [
          .init(line: 5, text: "another pattern", isMatch: true),
        ]),
      ],
      rootPath: "/test",
      hasMore: false)
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = ToolUseViewModel(
      status: status,
      input: .init(directoryPath: "/test", regex: "pattern", filePattern: nil))

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
    let output = Schema.SearchFilesToolOutput(
      outputForLLm: "Search results",
      results: [
        .init(path: "/test/file1.swift", searchResults: [
          .init(line: 1, text: "test pattern", isMatch: true),
        ]),
      ],
      rootPath: "/test",
      hasMore: true)
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = ToolUseViewModel(
      status: status,
      input: .init(directoryPath: "/test", regex: "test.*pattern", filePattern: "*.swift"))

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
    let error = AppError("Directory not found")
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .completed(.failure(error)))

    let viewModel = ToolUseViewModel(
      status: status,
      input: .init(directoryPath: "/test", regex: "pattern", filePattern: nil))

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
    let output = Schema.SearchFilesToolOutput(
      outputForLLm: "No results",
      results: [],
      rootPath: "/test",
      hasMore: false)
    let (status, _) = SearchFilesTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = ToolUseViewModel(
      status: status,
      input: .init(directoryPath: "/test", regex: "nonexistent", filePattern: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Search(nonexistent)
        ⎿ Found 0 matches


      """)
  }
}
