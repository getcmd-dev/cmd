// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppFoundation
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import SettingsServiceInterface
import ShellServiceInterface
import SwiftTesting
import Testing
import ThreadSafe
import XcodeObserverServiceInterface
@testable import CodeCompletionService

// MARK: - WorkspaceInitializationTests

@Suite("Workspace Initialization Race Condition Tests")
struct WorkspaceInitializationTests {

  @Test("Does not send events to workspace before initialization completes")
  func doesNotSendEventsBeforeInitialization() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()

    let setupExpectation = expectation(description: "setUp called")
    let listFilesExpectation = expectation(description: "listFiles called")

    let setupCalls = Atomic<[URL]>([])
    let didOpenCalls = Atomic<[URL]>([])

    mockCodeCompletionProvider.onSetUp = { workspace in
      setupCalls.mutate { $0.append(workspace.url) }
      setupExpectation.fulfill()
    }

    mockCodeCompletionProvider.onDidOpen = { workspace, _, _, _ in
      #expect(setupExpectation.isFulfilled) // didOpen only be called after setup
      didOpenCalls.mutate { $0.append(workspace) }
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    // Create a mock that signals when listFiles is called
    mockXcodeObserver.onListFiles = { _, _ in
      listFilesExpectation.fulfill()
      return ListFilesResult(
        files: [URL(fileURLWithPath: "/workspace1/file1.swift")],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace1)
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      getPasteboardContent: { nil },
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: MockFileManager(),
      shellService: MockShellService())

    // when - send state changes rapidly before initialization completes
    let state1 = createXcodeState(workspace: workspace1, file: "/workspace1/file1.swift", content: "let x = 1")
    let state2 = createXcodeState(workspace: workspace1, file: "/workspace1/file1.swift", content: "let x = 2")

    mockXcodeObserver.mutableStatePublisher.send(state1)
    mockXcodeObserver.mutableStatePublisher.send(state2)

    // Wait for initialization to complete
    try await fulfillment(of: [listFilesExpectation, setupExpectation], timeout: 2)

    // then - setUp should be called exactly once
    #expect(setupCalls.value.count == 1)
    _ = sut
  }

  @Test("Handles multiple workspaces initializing concurrently")
  func handlesMultipleWorkspacesConcurrently() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let workspace2 = URL(fileURLWithPath: "/workspace2")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()

    let setup1Expectation = expectation(description: "workspace1 setUp called")
    let setup2Expectation = expectation(description: "workspace2 setUp called")

    let setupCalls = Atomic<[URL]>([])
    let listFilesCallCount = Atomic<Int>(0)

    mockCodeCompletionProvider.onSetUp = { workspace in
      setupCalls.mutate { $0.append(workspace.url) }
      if workspace.url == workspace1 {
        setup1Expectation.fulfillAtMostOnce()
      } else if workspace.url == workspace2 {
        setup2Expectation.fulfillAtMostOnce()
      }
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { workspace, _ in
      listFilesCallCount.mutate { $0 += 1 }
      return ListFilesResult(
        files: [workspace.appendingPathComponent("file1.swift")],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace)
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      getPasteboardContent: { nil },
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: MockFileManager(),
      shellService: MockShellService())

    // when - trigger initialization of both workspaces at the same time
    let state1 = createXcodeState(workspace: workspace1, file: "/workspace1/file1.swift", content: "let x = 1")
    let state2 = createXcodeState(workspace: workspace2, file: "/workspace2/file1.swift", content: "let y = 1")

    mockXcodeObserver.mutableStatePublisher.send(state1)
    mockXcodeObserver.mutableStatePublisher.send(state2)

    // Wait for both initializations to complete
    try await fulfillment(of: [setup1Expectation, setup2Expectation], timeout: 2)

    // then - both workspaces should be initialized exactly once
    #expect(listFilesCallCount.value == 2)
    #expect(setupCalls.value.count == 2)
    #expect(setupCalls.value.contains(workspace1))
    #expect(setupCalls.value.contains(workspace2))
    _ = sut
  }

  @Test("Prevents duplicate initialization of same workspace")
  func preventsDuplicateInitialization() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()

    let setupExpectation = expectation(description: "setUp called")
    let listFilesExpectation = expectation(description: "listFiles called")

    let setupCallCount = Atomic<Int>(0)
    let listFilesCallCount = Atomic<Int>(0)

    mockCodeCompletionProvider.onSetUp = { _ in
      setupCallCount.mutate { $0 += 1 }
      setupExpectation.fulfill()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { workspace, _ in
      listFilesCallCount.mutate { $0 += 1 }
      listFilesExpectation.fulfill()
      return ListFilesResult(
        files: [workspace.appendingPathComponent("file1.swift")],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace)
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      getPasteboardContent: { nil },
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: MockFileManager(),
      shellService: MockShellService())

    // when - trigger multiple state changes for the same workspace rapidly
    let state = createXcodeState(workspace: workspace1, file: "/workspace1/file1.swift", content: "let x = 1")

    // Send the same workspace state multiple times rapidly
    for _ in 0 ..< 5 {
      mockXcodeObserver.mutableStatePublisher.send(state)
    }

    // Wait for initialization to complete
    try await fulfillment(of: [setupExpectation, listFilesExpectation], timeout: 2)

    // then - initialization should only happen once
    #expect(listFilesCallCount.value == 1)
    #expect(setupCallCount.value == 1)
    _ = sut
  }

  @Test("Updates recent edits tracker on file changes")
  func updatesRecentEditsTrackerOnFileChanges() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()

    let setupExpectation = expectation(description: "setUp called")
    let listFilesExpectation = expectation(description: "listFiles called")

    mockCodeCompletionProvider.onSetUp = { _ in
      setupExpectation.fulfill()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    mockXcodeObserver.onListFiles = { _, _ in
      listFilesExpectation.fulfill()
      return ListFilesResult(
        files: [URL(fileURLWithPath: "/workspace1/file1.swift")],
        workspaceType: .xcodeProject,
        workspaceRoot: workspace1)
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      getPasteboardContent: { nil },
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: MockFileManager(),
      shellService: MockShellService())

    // when - send state changes with file edits
    let state1 = createXcodeState(workspace: workspace1, file: "/workspace1/file1.swift", content: "let x = 1")
    mockXcodeObserver.mutableStatePublisher.send(state1)

    // Wait for initialization
    try await fulfillment(of: [listFilesExpectation, setupExpectation], timeout: 2)

    // Send a content change
    let state2 = createXcodeState(workspace: workspace1, file: "/workspace1/file1.swift", content: "let x = 2")
    mockXcodeObserver.mutableStatePublisher.send(state2)

    // Give time for async processing
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms

    // then - verify tracker has edits
    let tracker = await sut.recentEditsTrackers[workspace1]
    #expect(tracker != nil)
    let history = await tracker?.editsHistory
    #expect(history?.count ?? 0 > 0)
    _ = sut
  }

  @Test("Retries failed workspace initialization")
  func retriesFailedWorkspaceInitialization() async throws {
    // given
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let mockCodeCompletionProvider = MockCodeCompletionProvider(id: "test-provider")
    let mockXcodeObserver = MockXcodeObserver()
    let mockSettingsService = MockSettingsService()

    let firstAttemptFailedExpectation = expectation(description: "first attempt failed and state set")
    let secondAttemptExpectation = expectation(description: "second listFiles attempt")
    let setupExpectation = expectation(description: "setUp called after retry")

    let listFilesCallCount = Atomic<Int>(0)
    let setupCallCount = Atomic<Int>(0)
    let failureProcessed = Atomic<Bool>(false)

    mockCodeCompletionProvider.onSetUp = { _ in
      setupCallCount.mutate { $0 += 1 }
      setupExpectation.fulfill()
    }

    mockSettingsService.update(setting: \.codeCompletionProviderId, to: "test-provider")

    // First call fails, second succeeds
    mockXcodeObserver.onListFiles = { workspace, _ in
      let callNumber = listFilesCallCount.value
      listFilesCallCount.mutate { $0 += 1 }

      if callNumber == 0 {
        // Fulfill expectation after a delay to ensure state is set
        Task {
          try? await Task.sleep(nanoseconds: 50_000_000) // 50ms for async didInitialize to complete
          failureProcessed.set(to: true)
          firstAttemptFailedExpectation.fulfill()
        }
        throw AppError("Simulated failure")
      } else {
        secondAttemptExpectation.fulfill()
        return ListFilesResult(
          files: [workspace.appendingPathComponent("file1.swift")],
          workspaceType: .xcodeProject,
          workspaceRoot: workspace)
      }
    }

    let sut = DefaultCodeCompletionService(
      xcodeObserver: mockXcodeObserver,
      getPasteboardContent: { nil },
      codeCompletionProviders: [mockCodeCompletionProvider],
      settingsService: mockSettingsService,
      fileManager: MockFileManager(),
      shellService: MockShellService())

    // when - trigger initialization, which will fail
    let state1 = createXcodeState(workspace: workspace1, file: "/workspace1/file1.swift", content: "let x = 1")
    mockXcodeObserver.mutableStatePublisher.send(state1)

    // Wait for first attempt to fail AND state to be set
    try await fulfillment(of: firstAttemptFailedExpectation, timeout: 2)

    // then - try again with a new state change (simulating user action)
    let state2 = createXcodeState(workspace: workspace1, file: "/workspace1/file2.swift", content: "let y = 2")
    mockXcodeObserver.mutableStatePublisher.send(state2)

    // Wait for retry to succeed
    try await fulfillment(of: [secondAttemptExpectation, setupExpectation], timeout: 2)

    // Verify retry worked
    #expect(listFilesCallCount.value == 2)
    #expect(setupCallCount.value == 1)
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

extension DefaultCodeCompletionService {
  init(
    xcodeObserver: MockXcodeObserver = MockXcodeObserver(),
    codeCompletionProviders: [any CodeCompletionProvider],
    settingsService: MockSettingsService = MockSettingsService(),
    fileManager: MockFileManager = MockFileManager(),
    shellService: MockShellService = MockShellService())
  {
    self.init(
      xcodeObserver: xcodeObserver,
      getPasteboardContent: { nil },
      codeCompletionProviders: codeCompletionProviders,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: shellService)
  }
}
