// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppFoundation
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Combine
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import SettingsServiceInterface
import SwiftTesting
import Testing
import ThreadSafe
import XcodeObserverServiceInterface
@testable import CodeCompletionService

// MARK: - FileWatcherTests

@Suite("File Watcher Tests")
struct FileWatcherTests {

  @Test("Detects file save and notifies providers")
  func detectsFileSaveAndNotifiesProviders() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let file1 = URL(fileURLWithPath: "/workspace1/file1.swift")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()
    let mockFileManager = MockFileManager(
      files: [file1: "let x = 1"],
      directories: [workspace1])

    let setupExpectation = expectation(description: "setUp called")
    let didOpenExpectation = expectation(description: "didOpen called")
    let didSaveExpectation = expectation(description: "didSave called")

    let didSaveCalls = Atomic<[(workspace: any Workspace, file: URL, content: String, version: Int)]>([])

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockCodeCompletionProvider.onDidOpen = { _, _, _, _ in
      didOpenExpectation.fulfill()
    }

    mockCodeCompletionProvider.onDidSave = { workspace, file, content, version in
      didSaveCalls.mutate { $0.append((workspace, file, content, version)) }
      didSaveExpectation.fulfill()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { _, _ in
      ListFilesResult(
        files: [file1],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace1)
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: mockFileManager)

    // when - open a file in Xcode
    let state1 = createXcodeState(workspace: workspace1, file: file1.path, content: "let x = 1")
    mockXcodeObserver.mutableStatePublisher.send(state1)

    try await fulfillment(of: [setupExpectation, didOpenExpectation])

    // Simulate file save by changing content on disk and triggering watcher
    try mockFileManager.write(string: "let x = 2", to: file1, options: [])
    let modifiedEvent = FileSystemEvent(
      path: file1.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 1)!
    mockFileManager.triggerDirectoryChange(for: workspace1, events: [modifiedEvent])

    // Wait for didSave to be called
    try await fulfillment(of: didSaveExpectation)

    // then - didSave should be called with updated content
    #expect(didSaveCalls.value.count == 1)
    let saveCall = try #require(didSaveCalls.value.first)
    #expect(saveCall.workspace.url == workspace1)
    #expect(saveCall.file == file1)
    #expect(saveCall.content == "let x = 2")
    #expect(saveCall.version == 1) // version should increment
    _ = sut
  }

  @Test("Does not notify when file content hasn't changed")
  func doesNotNotifyWhenContentUnchanged() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let file1 = URL(fileURLWithPath: "/workspace1/file1.swift")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()
    let mockFileManager = MockFileManager(
      files: [file1: "let x = 1"],
      directories: [workspace1])

    let setupExpectation = expectation(description: "setUp called")
    let didSaveCalls = Atomic(0)

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockCodeCompletionProvider.onDidSave = { _, _, _, _ in
      didSaveCalls.increment()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { _, _ in
      ListFilesResult(
        files: [file1],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace1)
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: mockFileManager)

    // when - open a file and trigger watcher without changing content
    let state1 = createXcodeState(workspace: workspace1, file: file1.path, content: "let x = 1")
    mockXcodeObserver.mutableStatePublisher.send(state1)

    try await fulfillment(of: setupExpectation)

    // Trigger watcher but content is same
    let modifiedEvent = FileSystemEvent(
      path: file1.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 1)!
    mockFileManager.triggerDirectoryChange(for: workspace1, events: [modifiedEvent])

    // then - didSave should not be called
    #expect(didSaveCalls.value == 0)
    _ = sut
  }

  @Test("Handles file deletion gracefully")
  func handlesFileDeletionGracefully() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let file1 = URL(fileURLWithPath: "/workspace1/file1.swift")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()
    let mockFileManager = MockFileManager(
      files: [file1: "let x = 1"],
      directories: [workspace1])

    let setupExpectation = expectation(description: "setUp called")
    let didSaveCalls = Atomic(0)

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockCodeCompletionProvider.onDidSave = { _, _, _, _ in
      didSaveCalls.increment()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { _, _ in
      ListFilesResult(
        files: [file1],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace1)
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: mockFileManager)

    // when - open a file (this will work initially), then trigger watcher
    let state1 = createXcodeState(workspace: workspace1, file: file1.path, content: "let x = 1")
    mockXcodeObserver.mutableStatePublisher.send(state1)

    try await fulfillment(of: setupExpectation)

    // Delete the file and trigger watcher
    try mockFileManager.removeItem(atPath: file1.path)
    let modifiedEvent = FileSystemEvent(
      path: file1.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 1)!
    mockFileManager.triggerDirectoryChange(for: workspace1, events: [modifiedEvent])

    // then - should not crash and should not call didSave
    #expect(didSaveCalls.value == 0)
    _ = sut
  }

  @Test("Cleans up file watcher when workspace is closed")
  func cleansUpFileWatcherWhenWorkspaceClosed() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let file1 = URL(fileURLWithPath: "/workspace1/file1.swift")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()
    let mockFileManager = MockFileManager(
      files: [file1: "let x = 1"],
      directories: [workspace1])

    let setupExpectation = expectation(description: "setUp called")
    let closeExpectation = expectation(description: "close called")

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockCodeCompletionProvider.onClose = { _ in
      closeExpectation.fulfill()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { _, _ in
      ListFilesResult(
        files: [file1],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace1)
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: mockFileManager)

    // when - open workspace then close it
    let state1 = createXcodeState(workspace: workspace1, file: file1.path, content: "let x = 1")
    mockXcodeObserver.mutableStatePublisher.send(state1)

    try await fulfillment(of: setupExpectation)

    // Close workspace
    let emptyState = AXState<XcodeState>.state(XcodeState(
      activeApplicationProcessIdentifier: 123,
      previousApplicationProcessIdentifier: nil,
      xcodesState: []))
    mockXcodeObserver.mutableStatePublisher.send(emptyState)

    // Wait for cleanup
    try await fulfillment(of: closeExpectation)

    // then - watcher should be cancelled
    _ = sut
  }

  @Test("Calls XcodeObserver.listFiles with debounce when file watcher triggers")
  func callsListFilesWithDebounceOnWatcherEvent() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let file1 = URL(fileURLWithPath: "/workspace1/file1.swift")
    let file2 = URL(fileURLWithPath: "/workspace1/file2.swift")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()
    let mockFileManager = MockFileManager(
      files: [
        file1: "let x = 1",
        file2: "let y = 2",
      ],
      directories: [workspace1])

    let setupExpectation = expectation(description: "setUp called")
    let listFilesCallCount = Atomic(0)
    let listFilesCallsWithDebounce = Atomic<[(workspace: URL, debounce: TimeInterval?)]>([])

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")
    let listFilesCalledTwice = expectation(description: "List files called twice")

    // Track listFiles calls and their debounce parameters
    mockXcodeObserver.onListFiles = { workspace, debounce in
      let count = listFilesCallCount.increment()
      if count == 2 {
        listFilesCalledTwice.fulfill()
      }
      listFilesCallsWithDebounce.mutate { $0.append((workspace, debounce)) }
      return ListFilesResult(
        files: [file1, file2],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace1)
    }

    // Track filterIgnoredFiles calls to verify it's called before listFiles
    let filterIgnoredFilesCalls = Atomic(0)
    mockXcodeObserver.onFilterIgnoredFiles = { files, _ in
      filterIgnoredFilesCalls.increment()
      return files // Return all files unfiltered for this test
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: mockFileManager)

    // when - open a file in Xcode to initialize workspace
    let state1 = createXcodeState(workspace: workspace1, file: file1.path, content: "let x = 1")
    mockXcodeObserver.mutableStatePublisher.send(state1)

    try await fulfillment(of: setupExpectation)

    // Trigger file watcher event - modify file2
    try mockFileManager.write(string: "let y = 3", to: file2, options: [])
    let modifiedEvent = FileSystemEvent(
      path: file2.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 1)!
    mockFileManager.triggerDirectoryChange(for: workspace1, events: [modifiedEvent])

    try await fulfillment(of: listFilesCalledTwice)

    // then - verify the interaction between code completion service and XcodeObserver
    #expect(listFilesCallCount.value == 2)
    #expect(filterIgnoredFilesCalls.value == 1)

    // Verify that listFiles was called with debounce parameter
    #expect(
      listFilesCallsWithDebounce.value.map(\.debounce) == [nil, 5],
      "listFiles should be called with no delay the first time, then with delay")
    #expect(
      listFilesCallsWithDebounce.value.map(\.workspace) == [workspace1, workspace1],
      "listFiles should be called with correct workspace")

    _ = sut
  }

  @Test("Filters events through XcodeObserver before processing")
  func filtersEventsThroughXcodeObserver() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let file1 = URL(fileURLWithPath: "/workspace1/file1.swift")
    let ignoredFile = URL(fileURLWithPath: "/workspace1/.build/file2.swift")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()
    let mockFileManager = MockFileManager(
      files: [
        file1: "let x = 1",
        ignoredFile: "let y = 2",
      ],
      directories: [workspace1])

    let setupExpectation = expectation(description: "setUp called")
    let didSaveCalls = Atomic<[(file: URL, content: String)]>([])

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    let didCallOnSave = expectation(description: "onDidSave called")
    mockCodeCompletionProvider.onDidSave = { _, file, content, _ in
      didSaveCalls.mutate { $0.append((file, content)) }
      didCallOnSave.fulfillAtMostOnce()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")
    let listFilesCallCount = Atomic(0)
    let listFilesCalledTwice = expectation(description: "List files called twice")
    mockXcodeObserver.onListFiles = { _, _ in
      let count = listFilesCallCount.increment()
      if count == 2 {
        listFilesCalledTwice.fulfill()
      }
      return ListFilesResult(
        files: [file1], // Only file1, not ignoredFile
        workspaceType: .xcodeProject,
        workspaceRoot: workspace1)
    }

    // filterIgnoredFiles should filter out files in .build directory
    let filterIgnoredFilesCalls = Atomic<[(files: [URL], filtered: [URL])]>([])
    mockXcodeObserver.onFilterIgnoredFiles = { files, _ in
      let filtered = files.filter { !$0.path.contains(".build") }
      filterIgnoredFilesCalls.mutate { $0.append((files, filtered)) }
      return filtered
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: mockFileManager)

    // when - open file1 in Xcode
    let state1 = createXcodeState(workspace: workspace1, file: file1.path, content: "let x = 1")
    mockXcodeObserver.mutableStatePublisher.send(state1)

    try await fulfillment(of: setupExpectation)

    // Trigger events for both files
    try mockFileManager.write(string: "let x = 2", to: file1, options: [])
    try mockFileManager.write(string: "let y = 3", to: ignoredFile, options: [])

    let event1 = FileSystemEvent(
      path: file1.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 1)!
    let event2 = FileSystemEvent(
      path: ignoredFile.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 2)!

    mockFileManager.triggerDirectoryChange(for: workspace1, events: [event1, event2])

    try await fulfillment(of: [listFilesCalledTwice, didCallOnSave])

    // then - verify filterIgnoredFiles was called with both events
    #expect(filterIgnoredFilesCalls.value.count == 1, "filterIgnoredFiles should be called")
    let filterCall = try #require(filterIgnoredFilesCalls.value.first)
    #expect(filterCall.files.count == 2, "Both events should be passed to filterIgnoredFiles")
    #expect(filterCall.filtered.count == 1, "Only file1 should pass the filter")
    #expect(filterCall.filtered.first == file1, "file1 should be in filtered results")

    // Verify that only file1 triggered didSave (ignoredFile was filtered out)
    #expect(didSaveCalls.value.count == 1, "Only file1 should trigger didSave")
    let saveCall = try #require(didSaveCalls.value.first)
    #expect(saveCall.file == file1, "didSave should be called for file1")
    #expect(saveCall.content == "let x = 2", "Updated content should be passed to didSave")

    _ = sut
  }
}

// MARK: - Test Helpers

private func createXcodeState(workspace: URL, file: String, content: String) -> AXState<XcodeState> {
  let fileURL = URL(fileURLWithPath: file)
  let mockElement = AnyAXUIElement(
    isOnScreen: { true },
    raise: { },
    appKitFrame: { nil },
    cgFrame: { nil },
    pid: { 123 },
    setAppKitframe: { _ in },
    debugDescription: nil,
    id: "mock-element")

  return .state(XcodeState(
    activeApplicationProcessIdentifier: 123,
    previousApplicationProcessIdentifier: nil,
    xcodesState: [
      XcodeAppState(
        processIdentifier: 123,
        isActive: true,
        workspaces: [
          XcodeWorkspaceState(
            axElement: mockElement,
            url: workspace,
            editors: [
              XcodeEditorState(
                axElement: mockElement,
                fileName: fileURL.lastPathComponent,
                isFocused: true,
                content: content,
                selections: [CursorRange(
                  start: CursorPosition(line: 0, character: 0),
                  end: CursorPosition(line: 0, character: 0))],
                compilerMessages: []),
            ],
            isFocused: true,
            document: fileURL,
            tabs: [
              XcodeWorkspaceState.Tab(
                fileName: fileURL.lastPathComponent,
                isFocused: true,
                knownPath: fileURL,
                lastKnownContent: content),
            ]),
        ]),
    ]))
}
