// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppEventServiceInterface
import AppKit
import ChatAppEvents
import ChatFeatureInterface
import ChatFoundation
import ChatServiceInterface
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
  $0.userDefaults = MockUserDefaults()
  $0.chatHistoryService = MockChatHistoryService()
  $0.fileManager = MockFileManager()
  $0.llmService = MockLLMService()
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
  @Test("adding a new tab replaces the current one", .dependencies {
    $0.withAllModelAvailable()
  })
  func addingNewTabReplacesCurrentOne() async {
    // given
    let sut = ChatViewModel()
    let firstTab = sut.tab
    firstTab.input.textInput = TextInput([.text("Test input")])
    await firstTab.sendMessage()
    #expect(sut.tab.messages.count == 1)

    // when
    sut.addTab()

    // then
    #expect(sut.tab.messages.count == 0)
    #expect(sut.tab != firstTab)
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
    let filePath = try #require(URL(string: "file:///test/file.swift"))
    let content = "Test file content"
    let mockFileManager = MockFileManager(files: [
      filePath.path(): content,
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
