// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Combine
import ConcurrencyFoundation
import Dependencies
import FileSuggestionServiceInterface
import Foundation
import FoundationInterfaces
import LLMServiceInterface
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

// MARK: - ChatInputViewModelKeyboardTests

struct ChatInputViewModelKeyboardTests {

  @MainActor
  @Test("keyboard handling with no search results")
  func test_keyboardHandling_withNoSearchResults() {
    let viewModel = ChatInputViewModel()

    #expect(viewModel.handleOnKeyDown(key: .upArrow, modifiers: []) == false)
    #expect(viewModel.handleOnKeyDown(key: .downArrow, modifiers: []) == false)
    #expect(viewModel.handleOnKeyDown(key: .return, modifiers: []) == false)
    #expect(viewModel.handleOnKeyDown(key: .return, modifiers: [.shift]) == false)
    #expect(viewModel.handleOnKeyDown(key: .tab, modifiers: []) == false)
  }

  @MainActor
  @Test("keyboard handling with search results")
  func test_keyboardHandling_withSearchResults() async throws {
    let viewModel = ChatInputViewModel()
    let searchResults = [
      FileSuggestion(path: URL(filePath: "/path/to/file1.swift"), displayPath: "file1.swift", matchedRanges: []),
      FileSuggestion(path: URL(filePath: "/path/to/file2.swift"), displayPath: "file2.swift", matchedRanges: []),
      FileSuggestion(path: URL(filePath: "/path/to/file3.swift"), displayPath: "file3.swift", matchedRanges: []),
    ]
    let fileManager = MockFileManager(files: [
      "/path/to/file1.swift": "File 1 content",
      "/path/to/file2.swift": "File 2 content",
      "/path/to/file3.swift": "File 3 content",
    ])
    try await waitFor(viewModel, toHave: searchResults)

    withDependencies {
      $0.fileManager = fileManager
    } operation: {
      #expect(viewModel.selectedSearchResultIndex == 0)
      #expect(viewModel.handleOnKeyDown(key: .upArrow, modifiers: []) == true)
      #expect(viewModel.selectedSearchResultIndex == 0)
      #expect(viewModel.handleOnKeyDown(key: .downArrow, modifiers: []) == true)
      #expect(viewModel.selectedSearchResultIndex == 1)
      #expect(viewModel.handleOnKeyDown(key: .downArrow, modifiers: []) == true)
      #expect(viewModel.selectedSearchResultIndex == 2)
      #expect(viewModel.handleOnKeyDown(key: .downArrow, modifiers: []) == true)
      #expect(viewModel.selectedSearchResultIndex == 2) // No change since it's the last item
      #expect(viewModel.handleOnKeyDown(key: .upArrow, modifiers: []) == true)
      #expect(viewModel.selectedSearchResultIndex == 1)
      #expect(viewModel.handleOnKeyDown(key: .upArrow, modifiers: []) == true)
      #expect(viewModel.selectedSearchResultIndex == 0)
      #expect(viewModel.handleOnKeyDown(key: .upArrow, modifiers: []) == true)
      #expect(viewModel.selectedSearchResultIndex == 0) // No change since it's the first item

      #expect(viewModel.handleOnKeyDown(key: .return, modifiers: [.shift]) == false)
      #expect(viewModel.handleOnKeyDown(key: .return, modifiers: []) == true)

      // Validate search selection
      #expect(viewModel.attachments.count == 1)
      #expect(viewModel.attachments.first?.file?.path.path == "/path/to/file1.swift")
      #expect(viewModel.searchResults == nil)
      #expect(viewModel.inlineSearch == nil)
      #expect(viewModel.externalSearchQuery == nil)
    }
  }
}
