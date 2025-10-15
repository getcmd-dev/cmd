// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import Dependencies
import FileSuggestionServiceInterface
import Foundation
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

// MARK: - ChatInputViewModelFileHandlingTests

struct ChatInputViewModelFileHandlingTests {

  @MainActor
  @Test("handling normal text input changes don't change attachments")
  func test_handleNormalTextInputChanges() async throws {
    let viewModel = ChatInputViewModel()

    // Create file attachments
    let fileAttachment1 = AttachmentModel.file(.init(
      path: URL(filePath: "/path/to/file1.swift"),
      content: "// Test file content"))

    let fileAttachment2 = AttachmentModel.file(.init(
      path: URL(filePath: "/path/to/file2.swift"),
      content: "// Another test file"))

    // Add attachments
    viewModel.attachments = [fileAttachment1, fileAttachment2]

    // Create a new text input without references
    viewModel.textInput = TextInput([.text("No references here")])

    // Verify attachments are unchanged (since we're not using references)
    #expect(viewModel.attachments.count == 2)

    // Create a new text input with different content but still no references
    viewModel.textInput = TextInput([.text("Still no references")])

    // Verify attachments are unchanged
    #expect(viewModel.attachments.count == 2)
  }

  @MainActor
  @Test("handling inline search from text input")
  func test_handleInlineSearchFromTextInput() async throws {
    let viewModel = ChatInputViewModel()
    let fileSuggestionService = MockFileSuggestionService()
    let exp = expectation(description: "Search results updated")
    fileSuggestionService.onSuggestFiles = { query, _, _ in
      #expect(query == "test")
      return [
        FileSuggestion(path: URL(filePath: "/path/to/file1.swift"), displayPath: "file1.swift", matchedRanges: []),
      ]
    }

    withDependencies {
      $0.fileSuggestionService = fileSuggestionService
      $0.xcodeObserver = MockXcodeObserver(workspaceURL: URL(filePath: "/path/to/workspace"))
    } operation: {
      viewModel.inlineSearch = ("test", NSRange(location: 0, length: 4), nil)
    }

    let cancellable = viewModel.didSet(\.searchResults) { _ in
      exp.fulfill()
    }

    try await fulfillment(of: exp)
    #expect(viewModel.searchResults?.count == 1)
    _ = cancellable
  }

  @MainActor
  @Test
  func test_handleSearchFromSearchView() async throws {
    let viewModel = ChatInputViewModel()
    let fileSuggestionService = MockFileSuggestionService()
    let exp = expectation(description: "Search results updated")
    fileSuggestionService.onSuggestFiles = { query, _, _ in
      #expect(query == "test")
      return [
        FileSuggestion(path: URL(filePath: "/path/to/file1.swift"), displayPath: "file1.swift", matchedRanges: []),
      ]
    }

    withDependencies {
      $0.fileSuggestionService = fileSuggestionService
      $0.xcodeObserver = MockXcodeObserver(workspaceURL: URL(filePath: "/path/to/workspace"))
    } operation: {
      viewModel.externalSearchQuery = "test"
    }

    let cancellable = viewModel.didSet(\.searchResults) { _ in
      exp.fulfill()
    }

    try await fulfillment(of: exp)
    #expect(viewModel.searchResults?.count == 1)
    _ = cancellable
  }

}

/// A helper method that waits for the `searchResults` to be updated in the `ChatInputViewModel`.
@MainActor
func waitFor(_ chatInputViewModel: ChatInputViewModel, toHave searchResults: [FileSuggestion]) async throws {
  let fileSuggestionService = MockFileSuggestionService()
  let exp = expectation(description: "Search results updated")
  fileSuggestionService.onSuggestFiles = { _, _, _ in
    searchResults
  }

  withDependencies {
    $0.fileSuggestionService = fileSuggestionService
    $0.xcodeObserver = MockXcodeObserver(workspaceURL: URL(filePath: "/path/to/workspace"))
  } operation: {
    chatInputViewModel.externalSearchQuery = "test"
  }

  let cancellable = chatInputViewModel.didSet(\.searchResults) { _ in
    exp.fulfill()
  }

  try await fulfillment(of: exp)
  #expect(chatInputViewModel.searchResults == searchResults)
  _ = cancellable
}
