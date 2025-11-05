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
    let didSaveExpectation = expectation(description: "didSave called")

    let didSaveCalls = Atomic<[(workspace: URL, file: URL, content: String, version: Int)]>([])

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockCodeCompletionProvider.onDidSave = { workspace, file, content, version in
      didSaveCalls.mutate { $0.append((workspace, file, content, version)) }
      didSaveExpectation.fulfill()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { _ in
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

    // Wait for initialization
    try await fulfillment(of: setupExpectation, timeout: 2)

    // Simulate file save by changing content on disk and triggering watcher
    try mockFileManager.write(string: "let x = 2", to: file1, options: [])
    let modifiedEvent = FileSystemEvent(
      path: file1.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 1)!
    mockFileManager.triggerDirectoryChange(for: workspace1, events: [modifiedEvent])

    // Wait for didSave to be called
    try await fulfillment(of: didSaveExpectation, timeout: 2)

    // then - didSave should be called with updated content
    #expect(didSaveCalls.value.count == 1)
    let saveCall = try #require(didSaveCalls.value.first)
    #expect(saveCall.workspace == workspace1)
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
    let didSaveCalls = Atomic<Int>(0)

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockCodeCompletionProvider.onDidSave = { _, _, _, _ in
      didSaveCalls.mutate { $0 += 1 }
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { _ in
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

    try await fulfillment(of: setupExpectation, timeout: 2)

    // Trigger watcher but content is same
    let modifiedEvent = FileSystemEvent(
      path: file1.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 1)!
    mockFileManager.triggerDirectoryChange(for: workspace1, events: [modifiedEvent])

    // Give some time for potential didSave calls
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms

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
    let didSaveCalls = Atomic<Int>(0)

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockCodeCompletionProvider.onDidSave = { _, _, _, _ in
      didSaveCalls.mutate { $0 += 1 }
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { _ in
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

    try await fulfillment(of: setupExpectation, timeout: 2)

    // Delete the file and trigger watcher
    try mockFileManager.removeItem(atPath: file1.path)
    let modifiedEvent = FileSystemEvent(
      path: file1.path,
      flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified),
      eventId: 1)!
    mockFileManager.triggerDirectoryChange(for: workspace1, events: [modifiedEvent])

    // Give some time for potential processing
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms

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

    mockXcodeObserver.onListFiles = { _ in
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

    try await fulfillment(of: setupExpectation, timeout: 2)

    // Close workspace
    let emptyState = AXState<XcodeState>.state(XcodeState(
      activeApplicationProcessIdentifier: 123,
      previousApplicationProcessIdentifier: nil,
      xcodesState: []))
    mockXcodeObserver.mutableStatePublisher.send(emptyState)

    // Wait for cleanup
    try await fulfillment(of: closeExpectation, timeout: 2)

    // then - watcher should be cancelled
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
