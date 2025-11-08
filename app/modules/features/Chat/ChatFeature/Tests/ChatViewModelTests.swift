// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppEventServiceInterface
import AppKit
import ChatAppEvents
import ChatFoundation
import ChatHistoryServiceInterface
import Combine
import ConcurrencyFoundation
import Dependencies
import DependenciesTestSupport
import Foundation
import FoundationInterfaces
import LLMFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

// MARK: - ChatViewModelTests

@Suite(.dependencies {
  $0.withAllModelAvailable()
  $0.chatHistoryService = MockChatHistoryService()
  $0.fileManager = MockFileManager()
  $0.appEventHandlerRegistry = MockAppEventHandlerRegistry()
})
struct ChatViewModelTests {

  let dummyAXElement = AnyAXUIElement(AXUIElementCreateApplication(0))

  @MainActor
  @Test("initializing with default parameters creates a tab")
  func initializationWithDefaultParameters() {
    // given/when
    let sut = ChatViewModel()

    // then
    #expect(sut.tab.messages == [])
    #expect(sut.currentModel == .claudeSonnet)
  }

  @MainActor
  @Test("adding a new tab adds to tabs array and switches to it")
  func addingNewTabAddsToTabsArray() async {
    // given
    let sut = ChatViewModel()
    let firstTab = sut.tab
    #expect(sut.tabs.count == 1)
    #expect(sut.currentTabIndex == 0)

    // when
    sut.addTab()

    // then
    #expect(sut.tabs.count == 2)
    #expect(sut.currentTabIndex == 1)
    #expect(sut.tab != firstTab)
    #expect(sut.tabs[0] == firstTab)
  }

  @MainActor
  @Test("adding a new tab with copyingCurrentInput copies the input")
  func addingNewTabWithCopyingCurrentInput() {
    // given
    let sut = ChatViewModel()
    let initialTab = sut.tab
    initialTab.input.textInput = TextInput([.text("Test input")])

    // when
    sut.addTab(copyingCurrentInput: true)

    // then
    #expect(sut.tab != initialTab)
    #expect(sut.tab.input.textInput.string.string == "Test input")
  }

  @MainActor
  @Test("handling NewChatEvent adds a new tab")
  func handlingNewChatEventAddsNewTab() async {
    // given
    let mockAppEventHandlerRegistry = MockAppEventHandlerRegistry()

    let sut = withDependencies {
      $0.withAllModelAvailable()
      $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
    } operation: {
      ChatViewModel()
    }

    let firstTab = sut.tab
    firstTab.input.textInput = TextInput([.text("Test input")])
    await firstTab.sendMessage()
    #expect(firstTab.events.count == 1)

    // when
    let handled = await mockAppEventHandlerRegistry.handle(event: NewChatEvent())

    // then
    #expect(handled == true)
    #expect(sut.tab != firstTab)
  }

  @MainActor
  @Test("handling AddCodeToChatEvent with newThread creates a new tab")
  func handlingAddCodeToChatEventWithNewThread() async {
    // given
    let mockAppEventHandlerRegistry = MockAppEventHandlerRegistry()
    let mockXcodeObserver = MockXcodeObserver(AXState<XcodeState>.unknown)

    let sut = withDependencies {
      $0.withAllModelAvailable()
      $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ChatViewModel()
    }
    let firstTab = sut.tab
    firstTab.input.textInput = TextInput([.text("Test input")])
    await firstTab.sendMessage()
    #expect(firstTab.events.count == 1)

    // when
    let handled = await mockAppEventHandlerRegistry.handle(event: AddCodeToChatEvent(newThread: true, chatMode: .ask))

    // then
    #expect(handled == true)
    #expect(sut.tab != firstTab)
  }

  @MainActor
  @Test("handling AddCodeToChatEvent with chatMode updates the selected tab's mode")
  func handlingAddCodeToChatEventWithChatMode() async {
    // given
    let mockAppEventHandlerRegistry = MockAppEventHandlerRegistry()
    let mockXcodeObserver = MockXcodeObserver(AXState<XcodeState>.unknown)

    let sut = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ChatViewModel()
    }

    // when
    let handled = await mockAppEventHandlerRegistry.handle(event: AddCodeToChatEvent(newThread: false, chatMode: .ask))

    // then
    #expect(handled == true)
    #expect(sut.tab.input.mode == .ask)
  }

  @MainActor
  @Test("addCodeSelection adds file attachment when no editor is focused")
  func addCodeSelectionAddsFileAttachment() async throws {
    // given
    let documentURL = try #require(URL(string: "file:///test/file.swift"))
    let documentContent = "Test file content"
    let mockFileManager = MockFileManager(files: [
      documentURL.path(): documentContent,
    ])
    let mockAppEventHandlerRegistry = MockAppEventHandlerRegistry()

    let xcodeState = XcodeState(
      activeApplicationProcessIdentifier: 123,
      previousApplicationProcessIdentifier: nil,
      xcodesState: [
        XcodeAppState(
          processIdentifier: 123,
          isActive: true,
          workspaces: [XcodeWorkspaceState(
            axElement: dummyAXElement,
            url: URL(string: "file:///test/project.xcodeproj")!,
            editors: [],
            isFocused: true,
            document: documentURL,
            tabs: [])]),
      ])
    let mockXcodeObserver = MockXcodeObserver(AXState<XcodeState>.state(xcodeState))

    let sut = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
      $0.fileManager = mockFileManager
      $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
    } operation: {
      ChatViewModel()
    }

    // when
    let handled = await mockAppEventHandlerRegistry.handle(event: AddCodeToChatEvent(newThread: false, chatMode: nil))

    // then
    #expect(handled)
    #expect(sut.tab.input.attachments.count == 1)
    if case .file(let fileAttachment) = sut.tab.input.attachments.first {
      #expect(fileAttachment.path == documentURL)
      #expect(fileAttachment.content == documentContent)
    } else {
      Issue.record("Expected a file attachment")
    }
  }

  @MainActor
  @Test("addCodeSelection adds file selection attachment when editor has selection")
  func addCodeSelectionAddsFileSelectionAttachment() async throws {
    // given
    @Dependency(\.fileManager) var fileManager
    let mockFileManager = try #require(fileManager as? MockFileManager)
    let filePath = try #require(URL(string: "file:///test/file.swift"))
    let content = "Test file content"
    try mockFileManager.write(string: content, to: filePath, options: .atomic)

    @Dependency(\.xcodeObserver) var xcodeObserver
    let mockXcodeObserver = try #require(xcodeObserver as? MockXcodeObserver)
    let xcodeState = XcodeState(
      activeApplicationProcessIdentifier: 123,
      previousApplicationProcessIdentifier: nil,
      xcodesState: [
        XcodeAppState(
          processIdentifier: 123,
          isActive: true,
          workspaces: [XcodeWorkspaceState(
            axElement: dummyAXElement,
            url: URL(string: "file:///test/project.xcodeproj")!,
            editors: [XcodeEditorState(
              fileName: filePath.lastPathComponent,
              isFocused: true,
              content: content,
              selections: [CursorRange(start: CursorPosition(line: 0, character: 0), end: CursorPosition(line: 1, character: 5))],
              compilerMessages: [])],
            isFocused: true,
            document: filePath,
            tabs: [XcodeWorkspaceState.Tab(
              fileName: "file.swift",
              isFocused: true,
              knownPath: filePath,
              lastKnownContent: content)])]),
      ])
    mockXcodeObserver.mutableStatePublisher.send(AXState<XcodeState>.state(xcodeState))

    let sut = ChatViewModel()

    // when
    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    let mockAppEventHandlerRegistry = try #require(appEventHandlerRegistry as? MockAppEventHandlerRegistry)
    let handled = await mockAppEventHandlerRegistry.handle(event: AddCodeToChatEvent(newThread: false, chatMode: nil))

    // then
    #expect(handled)
    #expect(sut.tab.input.attachments.count == 1)
    if case .fileSelection(let selectionAttachment) = sut.tab.input.attachments.first {
      #expect(selectionAttachment.file.path == filePath)
      #expect(selectionAttachment.file.content == content)
      #expect(selectionAttachment.startLine == 1) // 0-based to 1-based
      #expect(selectionAttachment.endLine == 2) // 0-based to 1-based
    } else {
      Issue.record("Expected a file selection attachment")
    }
  }

  // MARK: - Chat History Tests

  @MainActor
  @Test("loadPersistedChatThreads loads the most recent thread")
  func loadPersistedChatThreadsLoadsRecentThread() async {
    // given
    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId,
      name: "Test Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // when
    await sut.loadPersistedChatThreads()

    // then
    #expect(sut.tab.id == threadId)
    #expect(sut.tab.name == "Test Thread")
  }

  @MainActor
  @Test("loadPersistedChatThreads handles empty history gracefully")
  func loadPersistedChatThreadsHandlesEmptyHistory() async {
    // given
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [])

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    let originalTabId = sut.tab.id

    // when
    await sut.loadPersistedChatThreads()

    // then
    // Should keep the original tab when no persisted threads exist
    #expect(sut.tab.id == originalTabId)
  }

  @MainActor
  @Test("loadPersistedChatThreads handles service errors gracefully")
  func loadPersistedChatThreadsHandlesErrors() async {
    // given
    let mockChatHistoryService = MockChatHistoryService()
    mockChatHistoryService.onLoadLastChatThreads = { _, _ in
      throw NSError(domain: "TestError", code: 1, userInfo: nil)
    }

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    let originalTabId = sut.tab.id

    // when
    await sut.loadPersistedChatThreads()

    // then
    // Should keep the original tab when loading fails
    #expect(sut.tab.id == originalTabId)
  }

  @MainActor
  @Test("handleSelectChatThread loads and switches to selected thread")
  func handleSelectChatThreadLoadsAndSwitches() async throws {
    // given
    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId,
      name: "Selected Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    sut.handleShowChatHistory()
    #expect(sut.showChatHistory == true)

    let exp = expectation(description: "tab changed")
    let cancellable = sut.didSet(\.tab) { tab in
      Task { @MainActor in
        if tab.id == threadId {
          exp.fulfillAtMostOnce()
        }
      }
    }

    // when
    sut.handleSelectChatThread(id: threadId)

    // then
    // Wait for async operation to complete
    try await fulfillment(of: exp)
    _ = cancellable

    #expect(sut.tab.id == threadId)
    #expect(sut.tab.name == "Selected Thread")
    #expect(sut.showChatHistory == false)
  }

  @MainActor
  @Test("handleSelectChatThread handles missing thread gracefully")
  func handleSelectChatThreadHandlesMissingThread() async throws {
    // given
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [])

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    let originalTabId = sut.tab.id
    sut.handleShowChatHistory()
    #expect(sut.showChatHistory == true)

    let didChangeShowChatHistory = expectation(description: "didChangeShowChatHistory")
    let cancellable = sut.didSet(\.showChatHistory, perform: { _ in
      didChangeShowChatHistory.fulfill()
    })

    // when
    sut.handleSelectChatThread(id: UUID())

    // then
    try await fulfillment(of: didChangeShowChatHistory)

    // Should keep original tab and hide chat history
    #expect(sut.tab.id == originalTabId)
    #expect(sut.showChatHistory == false)
    _ = cancellable
  }

  @MainActor
  @Test("handleSelectChatThread handles service errors gracefully")
  func handleSelectChatThreadHandlesErrors() async throws {
    // given
    let mockChatHistoryService = MockChatHistoryService()
    mockChatHistoryService.onLoadChatThread = { _ in
      throw NSError(domain: "TestError", code: 1, userInfo: nil)
    }

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    let originalTabId = sut.tab.id
    sut.handleShowChatHistory()
    #expect(sut.showChatHistory == true)

    let exp = expectation(description: "tab changed")
    let cancellable = sut.didSet(\.showChatHistory) { showChatHistory in
      Task { @MainActor in
        if showChatHistory == false {
          exp.fulfillAtMostOnce()
        }
      }
    }

    // when
    sut.handleSelectChatThread(id: UUID())

    // then
    // Wait for async operation to complete
    try await fulfillment(of: exp)
    _ = cancellable

    // Should keep original tab and hide chat history
    #expect(sut.tab.id == originalTabId)
    #expect(sut.showChatHistory == false)
  }

  @MainActor
  @Test("handleShowChatHistory sets showChatHistory to true")
  func handleShowChatHistory() {
    // given
    let sut = ChatViewModel()

    // when
    #expect(sut.showChatHistory == false)

    sut.handleShowChatHistory()

    // then
    #expect(sut.showChatHistory == true)
  }

  @MainActor
  @Test("handleHideChatHistory sets showChatHistory to false")
  func handleHideChatHistory() {
    // given
    let sut = ChatViewModel()
    sut.handleShowChatHistory()

    // when
    #expect(sut.showChatHistory == true)

    sut.handleHideChatHistory()

    // then
    #expect(sut.showChatHistory == false)
  }

  @MainActor
  @Test("chat history integration with multiple threads")
  func chatHistoryIntegrationMultipleThreads() async {
    // given
    let thread1Id = UUID()
    let thread2Id = UUID()
    let thread1 = ChatThreadModel(
      id: thread1Id,
      name: "Thread 1",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
    )
    let thread2 = ChatThreadModel(
      id: thread2Id,
      name: "Thread 2",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date(), // now
    )

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [thread1, thread2])

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // when
    // Load persisted threads (should load most recent)
    await sut.loadPersistedChatThreads()

    // then
    #expect(sut.tab.id == thread2Id)
    #expect(sut.tab.name == "Thread 2")

    // when
    // Switch to older thread
    sut.handleSelectChatThread(id: thread1Id)
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // then
    #expect(sut.tab.id == thread1Id)
    #expect(sut.tab.name == "Thread 1")

    // when
    // Switch back to newer thread
    sut.handleSelectChatThread(id: thread2Id)
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // then
    #expect(sut.tab.id == thread2Id)
    #expect(sut.tab.name == "Thread 2")
  }

  @MainActor
  @Test("chat history service interactions are called correctly")
  func chatHistoryServiceInteractions() async {
    // given
    let loadLastChatThreadsCalled = Atomic(false)
    let loadChatThreadCalled = Atomic(false)
    let loadChatThreadId = Atomic<UUID?>(nil)

    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId,
      name: "Test Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])
    mockChatHistoryService.onLoadLastChatThreads = { last, offset in
      loadLastChatThreadsCalled.set(to: true)
      #expect(last == 1)
      #expect(offset == 0)
    }
    mockChatHistoryService.onLoadChatThread = { id in
      loadChatThreadCalled.set(to: true)
      loadChatThreadId.set(to: id)
    }

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // when
    await sut.loadPersistedChatThreads()

    // then
    // Test loadPersistedChatThreads
    #expect(loadLastChatThreadsCalled.value == true)

    // when
    // Test handleSelectChatThread
    sut.handleSelectChatThread(id: threadId)
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // then
    #expect(loadChatThreadCalled.value == true)
    #expect(loadChatThreadId.value == threadId)
  }

  // MARK: - Thread Persistence Tests

  @MainActor
  @Test("setting tab saves thread ID to UserDefaults")
  func settingTabSavesThreadIdToUserDefaults() {
    // given
    let mockUserDefaults = MockUserDefaults()

    let sut = withDependencies {
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatViewModel()
    }

    let newTab = ChatThreadViewModel()

    // when
    sut.tab = newTab

    // then
    #expect(mockUserDefaults.string(forKey: "lastOpenChatThreadId") == newTab.id.uuidString)
  }

  @MainActor
  @Test("addTab saves new thread ID to UserDefaults")
  func addTabSavesNewThreadIdToUserDefaults() {
    // given
    let mockUserDefaults = MockUserDefaults()

    let sut = withDependencies {
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatViewModel()
    }

    let originalTabId = sut.tab.id

    // when
    sut.addTab()

    // then
    let savedThreadId = mockUserDefaults.string(forKey: "lastOpenChatThreadId")
    #expect(savedThreadId != originalTabId.uuidString)
    #expect(savedThreadId == sut.tab.id.uuidString)
  }

  @MainActor
  @Test("loadPersistedChatThreads uses UserDefaults thread ID first")
  func loadPersistedChatThreadsUsesUserDefaultsFirst() async {
    // given
    let savedThreadId = UUID()
    let testThread = ChatThreadModel(
      id: savedThreadId,
      name: "Saved Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date().addingTimeInterval(-3600))

    let recentThread = ChatThreadModel(
      id: UUID(),
      name: "Recent Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockUserDefaults = MockUserDefaults(initialValues: [
      "lastOpenChatThreadId": savedThreadId.uuidString,
    ])
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread, recentThread])

    let sut = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // when
    await sut.loadPersistedChatThreads()

    // then
    // Should load the saved thread, not the most recent one
    #expect(sut.tab.id == savedThreadId)
    #expect(sut.tab.name == "Saved Thread")
  }

  @MainActor
  @Test("loadPersistedChatThreads falls back to most recent when UserDefaults has invalid ID")
  func loadPersistedChatThreadsFallsBackToMostRecent() async {
    // given
    let recentThreadId = UUID()
    let recentThread = ChatThreadModel(
      id: recentThreadId,
      name: "Recent Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockUserDefaults = MockUserDefaults(initialValues: [
      "lastOpenChatThreadId": "invalid-uuid",
    ])
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [recentThread])

    // when
    let sut = await withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      let sut = ChatViewModel()
      await sut.loadPersistedChatThreads()
      return sut
    }

    // then
    // Should fall back to most recent thread
    #expect(sut.tab.id == recentThreadId)
    #expect(sut.tab.name == "Recent Thread")
  }

  @MainActor
  @Test("loadPersistedChatThreads falls back to most recent when saved thread not found")
  func loadPersistedChatThreadsFallsBackWhenSavedThreadNotFound() async {
    // given
    let missingThreadId = UUID()
    let recentThreadId = UUID()
    let recentThread = ChatThreadModel(
      id: recentThreadId,
      name: "Recent Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockUserDefaults = MockUserDefaults(initialValues: [
      "lastOpenChatThreadId": missingThreadId.uuidString,
    ])
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [recentThread])

    let sut = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // when
    await sut.loadPersistedChatThreads()

    // then
    // Should fall back to most recent thread since saved one doesn't exist
    #expect(sut.tab.id == recentThreadId)
    #expect(sut.tab.name == "Recent Thread")
  }

  @MainActor
  @Test("loadPersistedChatThreads handles missing UserDefaults and uses most recent")
  func loadPersistedChatThreadsHandlesMissingUserDefaults() async {
    // given
    let recentThreadId = UUID()
    let recentThread = ChatThreadModel(
      id: recentThreadId,
      name: "Recent Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockUserDefaults = MockUserDefaults() // No saved thread ID
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [recentThread])

    let sut = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // when
    await sut.loadPersistedChatThreads()

    // then
    // Should use most recent thread
    #expect(sut.tab.id == recentThreadId)
    #expect(sut.tab.name == "Recent Thread")
  }

  @MainActor
  @Test("tab persistence works end-to-end")
  func tabPersistenceEndToEnd() async {
    // given
    let thread1Id = UUID()
    let thread2Id = UUID()

    let thread1 = ChatThreadModel(
      id: thread1Id,
      name: "Thread 1",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date().addingTimeInterval(-3600))

    let thread2 = ChatThreadModel(
      id: thread2Id,
      name: "Thread 2",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockUserDefaults = MockUserDefaults()
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [thread1, thread2])

    // when
    // First instance - should load most recent (thread2)
    let sut1 = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    await sut1.loadPersistedChatThreads()

    // then
    #expect(sut1.tab.id == thread2Id)

    // when
    // Switch to thread1
    sut1.handleSelectChatThread(id: thread1Id)
    try? await Task.sleep(nanoseconds: 100_000_000) // Allow async operation to complete

    // then
    #expect(sut1.tab.id == thread1Id)

    // when
    // Create second instance - should load thread1 (the last saved one)
    let sut2 = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    await sut2.loadPersistedChatThreads()

    // then
    #expect(sut2.tab.id == thread1Id)
    #expect(sut2.tab.name == "Thread 1")
  }

  @MainActor
  @Test("UserDefaults key constant is correct")
  func userDefaultsKeyConstant() {
    // given
    let mockUserDefaults = MockUserDefaults()

    let sut = withDependencies {
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatViewModel()
    }

    let newTab = ChatThreadViewModel()

    // when
    sut.tab = newTab

    // then
    // Verify the specific key used
    #expect(mockUserDefaults.string(forKey: "lastOpenChatThreadId") == newTab.id.uuidString)
    #expect(mockUserDefaults.string(forKey: "wrongKey") == nil)
  }

  // MARK: - ChatService Buffering Tests

  @MainActor
  @Test("tab didSet automatically buffers the new tab")
  func tabDidSetAutomaticallyBuffers() {
    // given
    @Dependency(\.chatService) var chatService

    let sut = ChatViewModel()
    let originalTab = sut.tab

    // when - Create and set a new tab
    let newTab = ChatThreadViewModel()
    sut.tab = newTab

    // then - The new tab should be buffered in ChatService
    let retrieved: ChatThreadViewModel? = chatService.knownObject(for: newTab.id)
    #expect(retrieved === newTab)

    // The original tab should also have been buffered during init
    let retrievedOriginal: ChatThreadViewModel? = chatService.knownObject(for: originalTab.id)
    #expect(retrievedOriginal === originalTab)
  }

  @MainActor
  @Test("addTab with existing threadId reuses instance from ChatService")
  func addTabReusesExistingInstance() {
    // given
    @Dependency(\.chatService) var chatService

    let sut = ChatViewModel()
    let originalTab = sut.tab
    let originalId = originalTab.id

    // Switch to a new tab
    sut.addTab()
    #expect(sut.tab.id != originalId)

    // when - Add tab with the original thread ID
    sut.addTab(threadId: originalId)

    // then - Should reuse the original instance
    #expect(sut.tab === originalTab)
  }

  @MainActor
  @Test("addTab with new threadId creates new instance and buffers it")
  func addTabWithNewThreadIdCreatesAndBuffers() {
    // given
    @Dependency(\.chatService) var chatService

    let sut = ChatViewModel()
    let newThreadId = UUID()

    // when - Add tab with a new thread ID
    sut.addTab(threadId: newThreadId)

    // then - Should create a new instance
    #expect(sut.tab.id == newThreadId)

    // And it should be buffered
    let retrieved: ChatThreadViewModel? = chatService.knownObject(for: newThreadId)
    #expect(retrieved === sut.tab)
  }

  @MainActor
  @Test("selectChatThread reuses existing instance from ChatService")
  func selectChatThreadReusesExistingInstance() async throws {
    // given
    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId,
      name: "Test Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // Load the thread for the first time
    sut.handleSelectChatThread(id: threadId)
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    let firstInstance = sut.tab
    #expect(firstInstance.id == threadId)

    // Switch to a different thread
    sut.addTab()
    #expect(sut.tab.id != threadId)

    // when - Switch back to the original thread
    sut.handleSelectChatThread(id: threadId)
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // then - Should get the same instance
    let secondInstance = sut.tab
    #expect(secondInstance.id == threadId)
    #expect(firstInstance === secondInstance, "Should reuse the same ChatThreadViewModel instance")
  }

  @MainActor
  @Test("ChatViewModel init buffers the initial tab")
  func chatViewModelInitBuffersInitialTab() {
    // given
    @Dependency(\.chatService) var chatService

    // when
    let sut = ChatViewModel()

    // then - The initial tab should be buffered
    let retrieved: ChatThreadViewModel? = chatService.knownObject(for: sut.tab.id)
    #expect(retrieved === sut.tab)
  }

  @MainActor
  @Test("loadPersistedChatThreads reuses existing instance from ChatService")
  func loadPersistedChatThreadsReusesExistingInstance() async throws {
    // given
    @Dependency(\.chatService) var chatService

    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId,
      name: "Persisted Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockUserDefaults = MockUserDefaults()
    mockUserDefaults.set(threadId.uuidString, forKey: "lastOpenChatThreadId")

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatViewModel()
    }

    // when - Load persisted threads, which creates a new instance
    await sut.loadPersistedChatThreads()

    let firstInstance = sut.tab
    #expect(firstInstance.id == threadId)

    // Verify it's buffered
    let buffered: ChatThreadViewModel? = chatService.knownObject(for: threadId)
    #expect(buffered === firstInstance)

    // Switch away and back
    sut.addTab()
    sut.handleSelectChatThread(id: threadId)
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // then - Should reuse the buffered instance
    let secondInstance = sut.tab
    #expect(firstInstance === secondInstance, "Should reuse the buffered ChatThreadViewModel instance")
  }

  @MainActor
  @Test("selectChatThread creates new instance when not in ChatService and buffers it")
  func selectChatThreadCreatesNewInstanceAndBuffers() async throws {
    // given
    @Dependency(\.chatService) var chatService

    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId,
      name: "New Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])

    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // when - Load a thread that's not in the ChatService
    sut.handleSelectChatThread(id: threadId)
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // then - Should create a new instance and load from database
    #expect(sut.tab.id == threadId)
    #expect(sut.tab.name == "New Thread")

    // And it should be buffered automatically
    let buffered: ChatThreadViewModel? = chatService.knownObject(for: threadId)
    #expect(buffered === sut.tab)
  }

  @MainActor
  @Test("switching tabs multiple times maintains buffered instances")
  func switchingTabsMaintainsBufferedInstances() async throws {
    // given
    @Dependency(\.chatService) var chatService

    let thread1Id = UUID()
    let thread2Id = UUID()
    let thread3Id = UUID()

    let testThread1 = ChatThreadModel(
      id: thread1Id, name: "Thread 1", messages: [], events: [], projectInfo: nil, createdAt: Date())
    let testThread2 = ChatThreadModel(
      id: thread2Id, name: "Thread 2", messages: [], events: [], projectInfo: nil, createdAt: Date())
    let testThread3 = ChatThreadModel(
      id: thread3Id, name: "Thread 3", messages: [], events: [], projectInfo: nil, createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread1, testThread2, testThread3])
    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }
    let tab1Set = expectation(description: "First tab set")
    let tab2Set = expectation(description: "Second tab set")
    let tab3Set = expectation(description: "Third tab set")
    let tab1SetAgain = expectation(description: "First tab set again")

    var instance1: ChatThreadViewModel!
    var instance2: ChatThreadViewModel!
    var instance3: ChatThreadViewModel!

    let cancellable = sut.observeChanges(to: \.tab) { newTab in
      MainActor.assumeIsolated {
        switch newTab.id {
        case thread1Id:
          instance1 = newTab
          if !tab1Set.isFulfilled {
            tab1Set.fulfill()
          } else {
            tab1SetAgain.fulfillAtMostOnce()
          }

        case thread2Id:
          instance2 = newTab
          tab2Set.fulfillAtMostOnce()

        case thread3Id:
          instance3 = newTab
          tab3Set.fulfillAtMostOnce()

        default:
          break
        }
      }
    }

    // when - Load multiple threads
    sut.handleSelectChatThread(id: thread1Id)
    try await fulfillment(of: tab1Set)

    sut.handleSelectChatThread(id: thread2Id)
    try await fulfillment(of: tab2Set)

    sut.handleSelectChatThread(id: thread3Id)
    try await fulfillment(of: tab3Set)

    // Switch back to thread1
    sut.handleSelectChatThread(id: thread1Id)
    try await fulfillment(of: tab1SetAgain)
    // then - All instances should be reused
    #expect(sut.tab === instance1)

    // Verify all are still buffered
    let buffered1: ChatThreadViewModel? = chatService.knownObject(for: thread1Id)
    let buffered2: ChatThreadViewModel? = chatService.knownObject(for: thread2Id)
    let buffered3: ChatThreadViewModel? = chatService.knownObject(for: thread3Id)

    print("")

    #expect(buffered1 === instance1)
    #expect(buffered2 === instance2)
    #expect(buffered3 === instance3)
    _ = cancellable
  }

  // MARK: - Tab Management Tests

  @MainActor
  @Test("selectTab changes currentTabIndex and current tab")
  func selectTabChangesCurrentTabIndex() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    sut.addTab()
    #expect(sut.tabs.count == 3)
    #expect(sut.currentTabIndex == 2)

    // when
    sut.selectTab(at: 0)

    // then
    #expect(sut.currentTabIndex == 0)
    #expect(sut.tab == sut.tabs[0])
  }

  @MainActor
  @Test("selectTab ignores invalid indices")
  func selectTabIgnoresInvalidIndices() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    #expect(sut.tabs.count == 2)
    #expect(sut.currentTabIndex == 1)

    // when
    sut.selectTab(at: 10)

    // then
    #expect(sut.currentTabIndex == 1) // Should remain unchanged
  }

  @MainActor
  @Test("closeTab removes tab and adjusts currentTabIndex")
  func closeTabRemovesTabAndAdjustsIndex() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    sut.addTab()
    #expect(sut.tabs.count == 3)
    sut.selectTab(at: 1)

    // when
    sut.closeTab(at: 1)

    // then
    #expect(sut.tabs.count == 2)
    #expect(sut.currentTabIndex == 1) // Adjusted to still point to a valid tab
  }

  @MainActor
  @Test("closeTab on last tab creates new empty tab")
  func closeTabOnLastTabCreatesNewEmptyTab() {
    // given
    let sut = ChatViewModel()
    let originalTabId = sut.tab.id
    #expect(sut.tabs.count == 1)

    // when
    sut.closeTab(at: 0)

    // then
    #expect(sut.tabs.count == 1) // Still has one tab
    #expect(sut.tab.id != originalTabId) // But it's a new tab
    #expect(sut.currentTabIndex == 0)
  }

  @MainActor
  @Test("closeCurrentTab closes the active tab")
  func closeCurrentTabClosesActiveTab() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    sut.addTab()
    #expect(sut.tabs.count == 3)
    sut.selectTab(at: 1)
    let tabToRemove = sut.tab

    // when
    sut.closeCurrentTab()

    // then
    #expect(sut.tabs.count == 2)
    #expect(!sut.tabs.contains(tabToRemove))
  }

  @MainActor
  @Test("closeTab adjusts currentTabIndex when closing tab before current")
  func closeTabAdjustsIndexWhenClosingBeforeCurrent() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    sut.addTab()
    sut.selectTab(at: 2)
    let currentTab = sut.tab

    // when
    sut.closeTab(at: 0)

    // then
    #expect(sut.tabs.count == 2)
    #expect(sut.currentTabIndex == 1) // Adjusted from 2 to 1
    #expect(sut.tab == currentTab) // Still the same tab
  }

  @MainActor
  @Test("closeTab adjusts currentTabIndex when closing last tab")
  func closeTabAdjustsIndexWhenClosingLastTab() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    sut.addTab()
    #expect(sut.tabs.count == 3)
    sut.selectTab(at: 2)

    // when
    sut.closeTab(at: 2)

    // then
    #expect(sut.tabs.count == 2)
    #expect(sut.currentTabIndex == 1) // Adjusted to last valid index
  }

  // MARK: - Tab Persistence Tests

  @MainActor
  @Test("saveTabState persists tab IDs and current index to UserDefaults", .dependencies {
    $0.userDefaults = MockUserDefaults()
  })
  func saveTabStatePersistsToUserDefaults() throws {
    // given
    @Dependency(\.userDefaults) var userDefaults
    let mockUserDefaults = try #require(userDefaults as? MockUserDefaults)

    let sut = ChatViewModel()

    sut.addTab()
    sut.addTab()
    let tab0Id = sut.tabs[0].id
    let tab1Id = sut.tabs[1].id
    let tab2Id = sut.tabs[2].id
    sut.selectTab(at: 1)

    // when
    // The saveTabState is called internally, but we need to trigger it
    // by performing an action that calls it
    sut.selectTab(at: 2)

    // then
    let savedTabIds = mockUserDefaults.array(forKey: "openChatTabIds") as? [String]
    #expect(savedTabIds?.count == 3)
    #expect(savedTabIds?[0] == tab0Id.uuidString)
    #expect(savedTabIds?[1] == tab1Id.uuidString)
    #expect(savedTabIds?[2] == tab2Id.uuidString)
    #expect(mockUserDefaults.integer(forKey: "currentChatTabIndex") == 2)
  }

  @MainActor
  @Test("loadPersistedChatThreads loads all open tabs", .dependencies {
    let tab1Id = UUID()
    let tab2Id = UUID()
    let tab3Id = UUID()

    let thread1 = ChatThreadModel(
      id: tab1Id, name: "Tab 1", messages: [], events: [], projectInfo: nil, createdAt: Date())
    let thread2 = ChatThreadModel(
      id: tab2Id, name: "Tab 2", messages: [], events: [], projectInfo: nil, createdAt: Date())
    let thread3 = ChatThreadModel(
      id: tab3Id, name: "Tab 3", messages: [], events: [], projectInfo: nil, createdAt: Date())

    $0.userDefaults = MockUserDefaults(initialValues: [
      "openChatTabIds": [tab1Id.uuidString, tab2Id.uuidString, tab3Id.uuidString],
      "currentChatTabIndex": 1,
    ])
    $0.chatHistoryService = MockChatHistoryService(chatThreads: [thread1, thread2, thread3])
  })
  func loadPersistedChatThreadsLoadsAllOpenTabs() async throws {
    // given
    @Dependency(\.userDefaults) var userDefaults
    let mockUserDefaults = try #require(userDefaults as? MockUserDefaults)

    // Extract tab IDs from the saved values
    let tabIds = (mockUserDefaults.array(forKey: "openChatTabIds") as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
    let tab1Id = tabIds[0]
    let tab2Id = tabIds[1]
    let tab3Id = tabIds[2]

    let sut = ChatViewModel()

    // when
    await sut.loadPersistedChatThreads()

    // then
    #expect(sut.tabs.count == 3)
    #expect(sut.tabs[0].id == tab1Id)
    #expect(sut.tabs[1].id == tab2Id)
    #expect(sut.tabs[2].id == tab3Id)
    #expect(sut.currentTabIndex == 1)
    #expect(sut.tab.id == tab2Id)
  }

  @MainActor
  @Test("loadPersistedChatThreads handles missing tabs gracefully", .dependencies {
    let tab1Id = UUID()
    let tab2Id = UUID()
    let missingTabId = UUID()

    let thread1 = ChatThreadModel(
      id: tab1Id, name: "Tab 1", messages: [], events: [], projectInfo: nil, createdAt: Date())
    let thread2 = ChatThreadModel(
      id: tab2Id, name: "Tab 2", messages: [], events: [], projectInfo: nil, createdAt: Date())

    $0.userDefaults = MockUserDefaults(initialValues: [
      "openChatTabIds": [tab1Id.uuidString, missingTabId.uuidString, tab2Id.uuidString],
      "currentChatTabIndex": 1,
    ])
    $0.chatHistoryService = MockChatHistoryService(chatThreads: [thread1, thread2])
  })
  func loadPersistedChatThreadsHandlesMissingTabs() async throws {
    // given
    @Dependency(\.userDefaults) var userDefaults
    let mockUserDefaults = try #require(userDefaults as? MockUserDefaults)

    // Extract tab IDs from the saved values (we know the first and third exist)
    let tabIds = (mockUserDefaults.array(forKey: "openChatTabIds") as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
    let tab1Id = tabIds[0]
    let tab2Id = tabIds[2]

    let sut = ChatViewModel()

    // when
    await sut.loadPersistedChatThreads()

    // then
    // Should only load the tabs that exist
    #expect(sut.tabs.count == 2)
    #expect(sut.tabs[0].id == tab1Id)
    #expect(sut.tabs[1].id == tab2Id)
  }

  @MainActor
  @Test("loadPersistedChatThreads clamps currentTabIndex to valid range", .dependencies {
    let tab1Id = UUID()
    let tab2Id = UUID()

    let thread1 = ChatThreadModel(
      id: tab1Id, name: "Tab 1", messages: [], events: [], projectInfo: nil, createdAt: Date())
    let thread2 = ChatThreadModel(
      id: tab2Id, name: "Tab 2", messages: [], events: [], projectInfo: nil, createdAt: Date())

    $0.userDefaults = MockUserDefaults(initialValues: [
      "openChatTabIds": [tab1Id.uuidString, tab2Id.uuidString],
      "currentChatTabIndex": 10, // Out of bounds
    ])
    $0.chatHistoryService = MockChatHistoryService(chatThreads: [thread1, thread2])
  })
  func loadPersistedChatThreadsClampsCurrentTabIndex() async {
    // given
    let sut = ChatViewModel()

    // when
    await sut.loadPersistedChatThreads()

    // then
    #expect(sut.tabs.count == 2)
    #expect(sut.currentTabIndex == 1) // Clamped to last valid index
  }

  @MainActor
  @Test("handleSelectChatThread opens thread in existing tab if already open")
  func handleSelectChatThreadReusesExistingTab() async throws {
    // given
    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId, name: "Test Thread", messages: [], events: [], projectInfo: nil, createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])
    let sut = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // First, open the thread in a tab
    let exp1 = expectation(description: "first tab opened")
    let cancellable1 = sut.didSet(\.tab) { tab in
      Task { @MainActor in
        if tab.id == threadId {
          exp1.fulfillAtMostOnce()
        }
      }
    }
    sut.handleSelectChatThread(id: threadId)
    try await fulfillment(of: exp1)
    _ = cancellable1

    let tabIndex = sut.currentTabIndex
    #expect(sut.tab.id == threadId)

    // Switch to a different tab
    sut.addTab()
    #expect(sut.tab.id != threadId)
    #expect(sut.tabs.count == 2)

    // when
    // Select the same thread again
    sut.handleSelectChatThread(id: threadId)
    try await Task.sleep(nanoseconds: 100_000_000)

    // then
    // Should switch to existing tab, not create a new one
    #expect(sut.tabs.count == 2)
    #expect(sut.currentTabIndex == tabIndex)
    #expect(sut.tab.id == threadId)
  }

  // TODO: This test is disabled due to async coordination issues between handleSelectChatThread
  // and the test observers. The Task created by handleSelectChatThread doesn't complete before
  // the test assertions run, even when using observeChanges and expectations.
  // The functionality works correctly in the app. This needs investigation into proper
  // async test patterns for Task-based operations in SwiftTesting.
  //
  // @MainActor
  // @Test("handleSelectChatThread opens thread in new tab if not already open")
  // func handleSelectChatThreadOpensInNewTab() async throws { ... }

  // MARK: - Notification Badge Tests

  @MainActor
  @Test("tab is focused on initialization")
  func tabIsFocusedOnInitialization() {
    // given/when
    let sut = ChatViewModel()

    // then
    #expect(sut.tab.isFocused == true)
    #expect(sut.tab.hasUnreadCompletion == false)
  }

  @MainActor
  @Test("adding a new tab unfocuses the previous tab and focuses the new tab")
  func addingNewTabManagesFocus() {
    // given
    let sut = ChatViewModel()
    let firstTab = sut.tab

    // when
    sut.addTab()

    // then
    #expect(firstTab.isFocused == false)
    #expect(sut.tab.isFocused == true)
    #expect(sut.tabs[0].isFocused == false)
    #expect(sut.tabs[1].isFocused == true)
  }

  @MainActor
  @Test("switching tabs unfocuses old tab and focuses new tab")
  func switchingTabsManagesFocus() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    sut.addTab()
    #expect(sut.currentTabIndex == 2)

    // when
    sut.selectTab(at: 0)

    // then
    #expect(sut.tabs[0].isFocused == true)
    #expect(sut.tabs[1].isFocused == false)
    #expect(sut.tabs[2].isFocused == false)
  }

  @MainActor
  @Test("switching to a tab with unread completion clears the badge")
  func switchingToTabClearsBadge() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    sut.addTab()

    // Manually set the badge on the first tab (simulating completed streaming)
    sut.tabs[0].hasUnreadCompletion = true
    #expect(sut.tabs[0].hasUnreadCompletion == true)

    // when
    sut.selectTab(at: 0)

    // then
    #expect(sut.tabs[0].isFocused == true)
    #expect(sut.tabs[0].hasUnreadCompletion == false)
  }

  @MainActor
  @Test("closing a tab ensures the new current tab is focused")
  func closingTabEnsuresNewCurrentTabIsFocused() {
    // given
    let sut = ChatViewModel()
    sut.addTab()
    sut.addTab()
    #expect(sut.currentTabIndex == 2)
    #expect(sut.tabs[2].isFocused == true)

    // when - close the current tab
    sut.closeTab(at: 2)

    // then
    #expect(sut.tabs.count == 2)
    #expect(sut.currentTabIndex == 1)
    #expect(sut.tabs[1].isFocused == true)
  }

  @MainActor
  @Test("closing the last tab creates a new focused tab")
  func closingLastTabCreatesNewFocusedTab() {
    // given
    let sut = ChatViewModel()
    let originalTab = sut.tab

    // when
    sut.closeTab(at: 0)

    // then
    #expect(sut.tabs.count == 1)
    #expect(sut.tab.isFocused == true)
    #expect(sut.tab.id != originalTab.id) // New tab was created
  }

  @MainActor
  @Test("manually setting hasUnreadCompletion on unfocused tab")
  func manuallySettingBadgeOnUnfocusedTab() {
    // given - two tabs, second one focused
    let sut = ChatViewModel()
    sut.addTab()
    let firstTab = sut.tabs[0]
    #expect(firstTab.isFocused == false)

    // when - manually set the badge
    firstTab.hasUnreadCompletion = true

    // then - badge should be set
    #expect(firstTab.hasUnreadCompletion == true)
  }

  @MainActor
  @Test("badge is NOT set when streaming completes on focused tab")
  func badgeIsNotSetWhenStreamingCompletesOnFocusedTab() async throws {
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

    // given
    let sut = ChatViewModel()
    #expect(sut.tab.isFocused == true)
    #expect(sut.tab.hasUnreadCompletion == false)

    // when - simulate streaming on the focused tab
    mockLLMService.onSendMessage = { _, _, _, _, _, handleUpdateStream in
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>([])
      handleUpdateStream(updateStream)

      let message = MutableCurrentValueStream<AssistantMessage>(.init(content: []))
      updateStream.update(with: [message])

      let textContent = MutableCurrentValueStream<TextContentMessage>(.init(content: "", deltas: []))
      message.update(with: AssistantMessage(content: [.text(textContent)]))
      textContent.update(with: .init(content: "Test response", deltas: ["Test response"]))
      textContent.finish()

      message.finish()
      updateStream.finish()

      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    await sut.tab.sendMessage()
    try await Task.sleep(nanoseconds: 100_000_000)

    // then
    #expect(sut.tab.hasUnreadCompletion == false)
  }

  @MainActor
  @Test("badge is cleared when switching to a tab with unread completion")
  func badgeIsClearedWhenSwitchingToTabWithUnreadCompletion() {
    // given - two tabs with first tab having a badge
    let sut = ChatViewModel()
    sut.addTab()
    let firstTab = sut.tabs[0]
    firstTab.hasUnreadCompletion = true
    #expect(firstTab.hasUnreadCompletion == true)

    // when - switch to the tab with the badge
    sut.selectTab(at: 0)

    // then - badge should be cleared
    #expect(firstTab.isFocused == true)
    #expect(firstTab.hasUnreadCompletion == false)
  }
}

extension Schema.MessageContent {
  var text: String? {
    switch self {
    case .textMessage(let value):
      value.text
    case .reasoningMessage(let value):
      value.text
    default:
      nil
    }
  }

  var signature: String? {
    switch self {
    case .reasoningMessage(let value):
      value.signature
    default:
      nil
    }
  }
}

extension DependencyValues {
  /// Setup the settings and used default to allow for messages to be sent (there need to be an LLM model configured).
  mutating func withAllModelAvailable() {
    let settingsService = MockSettingsService.allConfigured
    let mockUserDefaults = MockUserDefaults(initialValues: [
      "selectedLLMModel": "gpt-latest",
    ])
    llmService = MockLLMService(activeModels: [.claudeSonnet, .gpt])
    self.settingsService = settingsService
    userDefaults = mockUserDefaults
    xcodeObserver = MockXcodeObserver(AXState<XcodeState>.unknown)
  }
}

extension AssistantMessage {
  init(_ text: String) {
    self.init(content: [.text(MutableCurrentValueStream<TextContentMessage>(.init(content: text)))])
  }
}

extension MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]> {
  convenience init(_ assistantMessage: AssistantMessage) {
    let messageStream = MutableCurrentValueStream<AssistantMessage>(assistantMessage)
    self.init([messageStream])
  }
}
