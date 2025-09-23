// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CheckpointServiceInterface
import Combine
import Dependencies
import Foundation
import FoundationInterfaces
import LLMServiceInterface
import LocalServerServiceInterface
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

// MARK: - ChatThreadViewModelHelpersTests

struct ChatThreadViewModelHelpersTests {

  // MARK: - Tests

  @MainActor
  @Test("View model fetches existing files on creation")
  func viewModelFetchesExistingFilesOnCreation() async throws {
    // Setup
    let workspaceURL = URL(fileURLWithPath: "/test/workspace")
    let mockXcodeObserver = MockXcodeObserver(workspaceURL: workspaceURL)
    let mockFileManager = MockFileManager()
    let mockServer = MockLocalServer()
    mockServer.onPostRequest = { path, _, _ in
      if path == "listFiles" {
        // Create a mock response for the listFiles endpoint
        let fileInfo = Schema.ListedFileInfo(
          path: "/test/workspace/file1.swift",
          isFile: true,
          isDirectory: false,
          isSymlink: false,
          byteSize: 100,
          permissions: "rw-r--r--",
          createdAt: "2025-01-01T00:00:00Z",
          modifiedAt: "2025-01-01T00:00:00Z")

        let response = Schema.ListFilesToolOutput(
          files: [fileInfo])
        return try JSONEncoder().encode(response)
      }

      throw URLError(.badServerResponse)
    }
    let mockLLMService = MockLLMService()
    let mockCheckpointService = MockCheckpointService()

    // Test
    let sut = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
      $0.fileManager = mockFileManager
      $0.localServer = mockServer
      $0.llmService = mockLLMService
      $0.checkpointService = mockCheckpointService
    } operation: {
      ChatThreadViewModel()
    }

    let exp = expectation(description: "Messages updated")
    let cancellable = sut.didSet(\.messages) { _ in
      exp.fulfillAtMostOnce()
    }

    try await fulfillment(of: exp)

    // Assert
    let lastMessageContent = try #require(sut.messages.last?.content.first)
    switch lastMessageContent {
    case .nonUserFacingText(let textContent):
      #expect(textContent.text == """
        ### System Information:
          * macOS Version: unkonwn
          * Default Xcode Version: unknown
          * Swift Version: unknown
          * xcpretty is installed. Make sure to use it when relevant to improve build outputs
          * Current Workspace Directory: /test/workspace
          * Project root (root of all relative path): /test/workspace
          * Files (first 200):
        - ./
          - file1.swift
        """)

    default:
      Issue.record("Expected nonUserFacingText content")
    }
    _ = cancellable
  }

  @Test("formatFileListAsHierarchy creates proper hierarchy")
  func formatFileListAsHierarchy() {
    // Setup
    let files = [
      "/project/file1.swift",
      "/project/src/",
      "/project/src/main.swift",
      "/project/src/utils/test/helper.swift",
      "/project/src/view.swift",
    ].map { Schema.ListedFileInfo(path: $0) }

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - file1.swift
        - src/
          - main.swift
          - utils/
            - test/
              - helper.swift
          - view.swift
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy handles empty file list")
  func formatFileListAsHierarchyWithEmptyList() {
    // Setup
    let files = [Schema.ListedFileInfo]()

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy handles single file")
  func formatFileListAsHierarchyWithSingleFile() {
    // Setup
    let files = [Schema.ListedFileInfo(path: "/project/main.swift")]

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - main.swift
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy handles nested directories only")
  func formatFileListAsHierarchyWithDirectoriesOnly() {
    // Setup
    let files = [
      "/project/src/",
      "/project/src/utils/",
      "/project/tests/",
    ].map { Schema.ListedFileInfo(path: $0) }

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - src/
          - utils/
        - tests/
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy sorts files alphabetically")
  func formatFileListAsHierarchySortsAlphabetically() {
    // Setup
    let files = [
      "/project/zebra.swift",
      "/project/alpha.swift",
      "/project/beta.swift",
    ].map { Schema.ListedFileInfo(path: $0) }

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - alpha.swift
        - beta.swift
        - zebra.swift
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy handles complex nested structure")
  func formatFileListAsHierarchyWithComplexStructure() {
    // Setup
    let files = [
      "/project/Package.swift",
      "/project/Sources/MyLibrary/MyLibrary.swift",
      "/project/Sources/MyLibrary/Internal/Helper.swift",
      "/project/Tests/MyLibraryTests/MyLibraryTests.swift",
      "/project/Tests/",
      "/project/Sources/",
      "/project/README.md",
    ].map { Schema.ListedFileInfo(path: $0) }

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - Package.swift
        - README.md
        - Sources/
          - MyLibrary/
            - Internal/
              - Helper.swift
            - MyLibrary.swift
        - Tests/
          - MyLibraryTests/
            - MyLibraryTests.swift
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy handles files at root level only")
  func formatFileListAsHierarchyWithRootFilesOnly() {
    // Setup
    let files = [
      "/project/file1.txt",
      "/project/file2.swift",
      "/project/config.json",
    ].map { Schema.ListedFileInfo(path: $0) }

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - config.json
        - file1.txt
        - file2.swift
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy handles special characters in filenames")
  func formatFileListAsHierarchyWithSpecialCharacters() {
    // Setup
    let files = [
      "/project/file with spaces.swift",
      "/project/file-with-dashes.md",
      "/project/file_with_underscores.txt",
      "/project/special/file.test.swift",
    ].map { Schema.ListedFileInfo(path: $0) }

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - file with spaces.swift
        - file-with-dashes.md
        - file_with_underscores.txt
        - special/
          - file.test.swift
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy handles files out of the project root")
  func formatFileListAsHierarchyWithFilesOutOfProjectRoot() {
    // Setup
    let files = [
      "/project/src/",
      "/src/utils/outside-root-repo.md",
      "/project/tests/",
      "/project/tests/file.txt",
    ].map { Schema.ListedFileInfo(path: $0) }

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - src/
        - tests/
          - file.txt
      """

    #expect(result == expected)
  }

  @Test("formatFileListAsHierarchy adds message for truncated content")
  func formatFileListAsHierarchyAddsMessageForTruncatedContent() {
    // Setup
    let files = [
      ("/project/Package.swift", false),
      ("/project/Sources/MyLibrary/MyLibrary.swift", false),
      ("/project/Sources/MyLibrary/Internal/Helper.swift", false),
      ("/project/Sources/MyLibrary/Internal/", true),
      ("/project/Tests/MyLibraryTests/MyLibraryTests.swift", false),
      ("/project/Tests/", true),
      ("/project/Sources/", false),
      ("/project/README.md", false),
    ].map { Schema.ListedFileInfo(path: $0.0, hasMoreContent: $0.1) }

    // Test
    let result = ChatThreadViewModel.formatFileListAsHierarchy(filesInfo: files, projectRoot: URL(filePath: "/project"))

    // Assert
    let expected = """
      - ./
        - Package.swift
        - README.md
        - Sources/
          - MyLibrary/
            - Internal/ (truncated)
              - Helper.swift
            - MyLibrary.swift
        - Tests/ (truncated)
          - MyLibraryTests/
            - MyLibraryTests.swift
      """

    #expect(result == expected)
  }
}

extension Schema.ListedFileInfo {
  init(path: String, hasMoreContent: Bool = false) {
    self.init(
      path: path,
      isFile: !path.hasSuffix("/"),
      isDirectory: false,
      hasMoreContent: hasMoreContent,
      isSymlink: false,
      byteSize: 200,
      permissions: "rw-r--r--",
      createdAt: "2025-01-01T00:00:00Z",
      modifiedAt: "2025-01-01T00:00:00Z")
  }
}
