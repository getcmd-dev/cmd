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

// MARK: - ChatInputViewModelFileHandlingTests

struct DragDropTests {

  @MainActor
  @Test("file attachment creation through drop")
  func test_fileAttachmentCreation_throughDrop() async throws {
    // Setup mock file manager
    let mockFileManager = MockFileManager(files: [
      "/path/to/file.swift": "// Test file content",
      "/path/to/image.png": "image data",
    ])
    try withDependencies {
      $0.fileManager = mockFileManager
    } operation: {
      let viewModel = ChatInputViewModel()

      // Test creating a file attachment through drop
      let fileURL = URL(filePath: "/path/to/file.swift")
      _ = viewModel.handleDrop(of: .file(fileURL))

      #expect(viewModel.attachments.count == 1)
      let fileAttachment = try #require(viewModel.attachments[0].file)
      #expect(fileAttachment.path == fileURL)
      #expect(fileAttachment.content == "// Test file content")

      // Test creating a file attachment through drop
      let imageURL = URL(filePath: "/path/to/image.png")
      _ = viewModel.handleDrop(of: .file(imageURL))

      #expect(viewModel.attachments.count == 2)
      let imageAttachment = try #require(viewModel.attachments[1].image)
      #expect(imageAttachment.path == imageURL)
    }
  }

  @MainActor
  @Test("handling text drop")
  func test_handleDrop_text() {
    let viewModel = ChatInputViewModel(
      activeModels: [.claudeSonnet])

    let result = viewModel.handleDrop(of: .text("Dropped text"))

    #expect(result)
    #expect(viewModel.textInput.elements.count == 1)
    if case .text(let text) = viewModel.textInput.elements.first {
      #expect(text == "Dropped text")
    } else {
      #expect(Bool(false), "Expected text element")
    }
  }
}
