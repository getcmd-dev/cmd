// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatHistoryServiceInterface
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

  // MARK: - Attachment API Format Tests

  @Test("File attachment converts to API format correctly")
  func fileAttachmentConvertsToAPIFormat() throws {
    // Setup
    let fileURL = URL(filePath: "/project/main.swift")
    let content = "print(\"Hello, world!\")"
    let attachment = AttachmentModel.file(.init(
      id: UUID(),
      path: fileURL,
      content: content))

    // Test
    let apiFormat = attachment.apiFormat

    // Assert
    guard case .fileAttachment(let fileAttachment) = apiFormat else {
      Issue.record("Expected fileAttachment")
      return
    }
    #expect(fileAttachment.path == "/project/main.swift")
    #expect(fileAttachment.content == content)
  }

  @Test("File selection attachment converts to API format with correct line range")
  func fileSelectionAttachmentConvertsToAPIFormat() throws {
    // Setup
    let fileURL = URL(filePath: "/project/code.swift")
    let content = """
      line 1
      line 2
      line 3
      line 4
      line 5
      """
    let attachment = AttachmentModel.fileSelection(.init(
      id: UUID(),
      file: .init(id: UUID(), path: fileURL, content: content),
      startLine: 2,
      endLine: 4))

    // Test
    let apiFormat = attachment.apiFormat

    // Assert
    guard case .fileSelectionAttachment(let fileSelection) = apiFormat else {
      Issue.record("Expected fileSelectionAttachment")
      return
    }
    #expect(fileSelection.path == "/project/code.swift")
    #expect(fileSelection.startLine == 2)
    #expect(fileSelection.endLine == 4)
    #expect(fileSelection.content == "line 2\nline 3\nline 4")
  }

  @Test("Folder attachment converts to API format with entries")
  func folderAttachmentConvertsToAPIFormat() throws {
    // Setup
    let folderURL = URL(filePath: "/project/src")
    let entries = [
      AttachmentModel.FolderAttachmentModel.Entry(
        path: "/project/src/main.swift"),
      AttachmentModel.FolderAttachmentModel.Entry(
        path: "/project/src/utils"),
    ]
    let attachment = AttachmentModel.folder(.init(
      id: UUID(),
      path: folderURL,
      files: entries))

    // Test
    let apiFormat = attachment.apiFormat

    // Assert
    guard case .folderAttachment(let folderAttachment) = apiFormat else {
      Issue.record("Expected folderAttachment")
      return
    }
    #expect(folderAttachment.path == "/project/src")
    #expect(folderAttachment.entries.count == 2)
    #expect(folderAttachment.entries[0].path == "/project/src/main.swift")
    #expect(folderAttachment.entries[0].relativePath == "main.swift")
    #expect(folderAttachment.entries[1].path == "/project/src/utils")
    #expect(folderAttachment.entries[1].relativePath == "utils")
    #expect(folderAttachment.hasMoreContent == nil)
  }

  @Test("Folder attachment with more than 50 files limits entries and sets hasMoreContent")
  func folderAttachmentLimitsEntriesAndSetsHasMoreContent() throws {
    // Setup
    let folderURL = URL(filePath: "/project/large")
    let entries = (1...100).map { i in
      AttachmentModel.FolderAttachmentModel.Entry(
        path: "/project/large/file\(i).swift")
    }
    let attachment = AttachmentModel.folder(.init(
      id: UUID(),
      path: folderURL,
      files: entries))

    // Test
    let apiFormat = attachment.apiFormat

    // Assert
    guard case .folderAttachment(let folderAttachment) = apiFormat else {
      Issue.record("Expected folderAttachment")
      return
    }
    #expect(folderAttachment.path == "/project/large")
    #expect(folderAttachment.entries.count == 50)
    #expect(folderAttachment.entries[0].path == "/project/large/file1.swift")
    #expect(folderAttachment.entries[49].path == "/project/large/file50.swift")
    #expect(folderAttachment.hasMoreContent == true)
  }

  @Test("Folder attachment with exactly 50 files does not set hasMoreContent")
  func folderAttachmentWithExactly50FilesDoesNotSetHasMoreContent() throws {
    // Setup
    let folderURL = URL(filePath: "/project/exact")
    let entries = (1...50).map { i in
      AttachmentModel.FolderAttachmentModel.Entry(
        path: "/project/exact/file\(i).swift")
    }
    let attachment = AttachmentModel.folder(.init(
      id: UUID(),
      path: folderURL,
      files: entries))

    // Test
    let apiFormat = attachment.apiFormat

    // Assert
    guard case .folderAttachment(let folderAttachment) = apiFormat else {
      Issue.record("Expected folderAttachment")
      return
    }
    #expect(folderAttachment.entries.count == 50)
    #expect(folderAttachment.hasMoreContent == nil)
  }

  @Test("Folder attachment with 51 files limits to 50 and sets hasMoreContent")
  func folderAttachmentWith51FilesLimitsTo50() throws {
    // Setup
    let folderURL = URL(filePath: "/project/edge")
    let entries = (1...51).map { i in
      AttachmentModel.FolderAttachmentModel.Entry(
        path: "/project/edge/file\(i).swift")
    }
    let attachment = AttachmentModel.folder(.init(
      id: UUID(),
      path: folderURL,
      files: entries))

    // Test
    let apiFormat = attachment.apiFormat

    // Assert
    guard case .folderAttachment(let folderAttachment) = apiFormat else {
      Issue.record("Expected folderAttachment")
      return
    }
    #expect(folderAttachment.entries.count == 50)
    #expect(folderAttachment.hasMoreContent == true)
  }

  @Test("Folder attachment with empty files list")
  func folderAttachmentWithEmptyFilesList() throws {
    // Setup
    let folderURL = URL(filePath: "/project/empty")
    let attachment = AttachmentModel.folder(.init(
      id: UUID(),
      path: folderURL,
      files: []))

    // Test
    let apiFormat = attachment.apiFormat

    // Assert
    guard case .folderAttachment(let folderAttachment) = apiFormat else {
      Issue.record("Expected folderAttachment")
      return
    }
    #expect(folderAttachment.path == "/project/empty")
    #expect(folderAttachment.entries.isEmpty)
    #expect(folderAttachment.hasMoreContent == nil)
  }

  @Test("Build error attachment converts to API format")
  func buildErrorAttachmentConvertsToAPIFormat() throws {
    // Setup
    let filePath = URL(filePath: "/project/broken.swift")
    let attachment = AttachmentModel.buildError(.init(
      id: UUID(),
      message: "Type 'String' has no member 'foo'",
      filePath: filePath,
      line: 42,
      column: 10))

    // Test
    let apiFormat = attachment.apiFormat

    // Assert
    guard case .buildErrorAttachment(let buildError) = apiFormat else {
      Issue.record("Expected buildErrorAttachment")
      return
    }
    #expect(buildError.filePath == "/project/broken.swift")
    #expect(buildError.line == 42)
    #expect(buildError.column == 10)
    #expect(buildError.message == "Type 'String' has no member 'foo'")
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
