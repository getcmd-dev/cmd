// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatServiceInterface
import Dependencies
import DependenciesTestSupport
import Foundation
import FoundationInterfaces
import SwiftTesting
import Testing
import ToolFoundation
import XcodeObserverServiceInterface
@testable import EditFilesTool

@Suite("Edit file tool tests")
struct EditFileToolTests {

  @Test("BaselineContent persistence when file changes during tool lifecycle")
  func test_baselineContentPersistenceWhenFileChanges() async throws {
    // given
    let tool = EditFilesTool(shouldAutoApply: false)
    let toolsPlugin = ToolsPlugin()
    toolsPlugin.plugIn(tool: tool)
    let testFilePath = URL(filePath: "/src/TestFile.swift")
    let originalContent = "let value = 42"
    let modifiedContent = "let value = 100\nlet newValue = 200"

    let fileChange = EditFilesTool.Use.Input.FileChange(
      path: testFilePath.path,
      isNewFile: false,
      changes: [
        EditFilesTool.Use.Input.FileChange.Change(
          search: "let value = 42",
          replace: "let value = 24"),
      ])

    let input = EditFilesTool.Use.Input(files: [fileChange])

    let mockFileManager = MockFileManager(files: [testFilePath: originalContent])
    let mockChatContext = MockChatThreadContext(knownFilesContent: [testFilePath.path: originalContent])
    let mockChatContextRegistry = MockChatContextRegistryService(["mock-thread-id": mockChatContext])
    let toolExecutionContext = ToolExecutionContext(threadId: "mock-thread-id")

    let persistenceRequested = expectation(description: "Persistence requested")
    mockChatContext.onRequestPersistence = {
      persistenceRequested.fulfillAtMostOnce()
    }
    let createToolUseFromInput = {
      tool.use(toolUseId: "test-123", input: input, isInputComplete: true, context: toolExecutionContext)
    }

    try await withDependencies {
      $0.chatContextRegistry = mockChatContextRegistry
      $0.fileManager = mockFileManager
      $0.xcodeObserver = MockXcodeObserver(fileManager: mockFileManager)
    } operation: {
      // when - create tool use
      let toolUse = createToolUseFromInput()

      try await fulfillment(of: persistenceRequested)

      // then - persist the tool use to JSON
      let encodedData = try JSONEncoder().encode(toolUse)

      // change the file on disk
      try mockFileManager.write(string: modifiedContent, to: testFilePath, options: [])
      mockChatContext.set(knownFileContent: modifiedContent, for: testFilePath)

      // decode encoded data
      let decoder = JSONDecoder()
      decoder.userInfo.set(toolPlugin: toolsPlugin)
      let decodedToolUse = try decoder.decode(EditFilesTool.Use.self, from: encodedData)

      // create new tool use for comparison
      let newToolUse = createToolUseFromInput()

      #expect(toolUse.internalState?.convertedInput.first?.baseLineContent == originalContent)
      #expect(decodedToolUse.internalState?.convertedInput.first?.baseLineContent == originalContent)
      #expect(newToolUse.internalState?.convertedInput.first?.baseLineContent == modifiedContent)
    }
  }
}
