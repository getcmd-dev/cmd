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

struct ChatViewModelTests {
  let dummyAXElement = AnyAXUIElement(AXUIElementCreateApplication(0))

  @MainActor
  @Test("initializing with default parameters creates a tab")
  func test_initialization_withDefaultParameters() {
    let viewModel = ChatViewModel()

    #expect(viewModel.tab.messages == [])
    #expect(viewModel.currentModel == .claudeSonnet)
  }

  @MainActor
  @Test("adding a new tab replaces the current one")
  func test_addTab_increasesTabCount() async {
    let viewModel = withAllModelAvailable {
      ChatViewModel()
    }
    let firstTab = viewModel.tab
    firstTab.input.textInput = TextInput([.text("Test input")])
    await firstTab.sendMessage()
    #expect(viewModel.tab.messages.count == 1)
    viewModel.addTab()

    #expect(viewModel.tab.messages.count == 0)
    #expect(viewModel.tab != firstTab)
  }

  @MainActor
  @Test("adding a new tab with copyingCurrentInput copies the input")
  func test_addTab_withCopyingCurrentInput() {
    let viewModel = ChatViewModel()
    let initialTab = viewModel.tab

    // Set some input on the initial tab
    initialTab.input.textInput = TextInput([.text("Test input")])

    viewModel.addTab(copyingCurrentInput: true)

    #expect(viewModel.tab != initialTab)
    #expect(viewModel.tab.input.textInput.string.string == "Test input")
  }

  @MainActor
  @Test("handling NewChatEvent adds a new tab")
  func test_handleNewChatEvent() async {
    let mockAppEventHandlerRegistry = MockAppEventHandlerRegistry()

    let viewModel = withAllModelAvailable {
      withDependencies {
        $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
      } operation: {
        ChatViewModel()
      }
    }

    let firstTab = viewModel.tab
    firstTab.input.textInput = TextInput([.text("Test input")])
    await firstTab.sendMessage()
    #expect(firstTab.events.count == 1)

    let handled = await mockAppEventHandlerRegistry.handle(event: NewChatEvent())
    #expect(handled == true)

    // Verify a new tab was added
    #expect(viewModel.tab != firstTab)
  }

  @MainActor
  @Test("handling AddCodeToChatEvent with newThread creates a new tab")
  func test_handleAddCodeToChatEvent_withNewThread() async {
    let mockAppEventHandlerRegistry = MockAppEventHandlerRegistry()
    let mockXcodeObserver = MockXcodeObserver(AXState<XcodeState>.unknown)

    let viewModel = withAllModelAvailable { withDependencies {
      $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ChatViewModel()
    }
    }
    let firstTab = viewModel.tab
    firstTab.input.textInput = TextInput([.text("Test input")])
    await firstTab.sendMessage()
    #expect(firstTab.events.count == 1)

    let handled = await mockAppEventHandlerRegistry.handle(event: AddCodeToChatEvent(newThread: true, chatMode: .ask))
    #expect(handled == true)

    // Verify a new tab was added
    #expect(viewModel.tab != firstTab)
  }

  @MainActor
  @Test("handling AddCodeToChatEvent with chatMode updates the selected tab's mode")
  func test_handleAddCodeToChatEvent_withChatMode() async {
    let mockAppEventHandlerRegistry = MockAppEventHandlerRegistry()
    let mockXcodeObserver = MockXcodeObserver(AXState<XcodeState>.unknown)

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ChatViewModel()
    }

    let handled = await mockAppEventHandlerRegistry.handle(event: AddCodeToChatEvent(newThread: false, chatMode: .ask))
    #expect(handled == true)

    // Verify the selected tab's mode was updated
    #expect(viewModel.tab.input.mode == .ask)
  }

  @MainActor
  @Test("addCodeSelection adds file attachment when no editor is focused")
  func test_addCodeSelection_addsFileAttachment() async throws {
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

    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
      $0.fileManager = mockFileManager
      $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
    } operation: {
      ChatViewModel()
    }

    // Call the method through the event handler
    let handled = await mockAppEventHandlerRegistry.handle(event: AddCodeToChatEvent(newThread: false, chatMode: nil))
    #expect(handled)
    // Verify a file attachment was added
    #expect(viewModel.tab.input.attachments.count == 1)
    if case .file(let fileAttachment) = viewModel.tab.input.attachments.first {
      #expect(fileAttachment.path == documentURL)
      #expect(fileAttachment.content == documentContent)
    } else {
      Issue.record("Expected a file attachment")
    }
  }

  @MainActor
  @Test("addCodeSelection adds file selection attachment when editor has selection")
  func test_addCodeSelection_addsFileSelectionAttachment() async throws {
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

    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
      $0.fileManager = mockFileManager
      $0.appEventHandlerRegistry = mockAppEventHandlerRegistry
    } operation: {
      ChatViewModel()
    }

    let handled = await mockAppEventHandlerRegistry.handle(event: AddCodeToChatEvent(newThread: false, chatMode: nil))
    #expect(handled)

    // Verify a file selection attachment was added
    #expect(viewModel.tab.input.attachments.count == 1)
    if case .fileSelection(let selectionAttachment) = viewModel.tab.input.attachments.first {
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
  func test_loadPersistedChatThreads_loadsRecentThread() async {
    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId,
      name: "Test Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])

    let viewModel = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    await viewModel.loadPersistedChatThreads()

    #expect(viewModel.tab.id == threadId)
    #expect(viewModel.tab.name == "Test Thread")
  }

  @MainActor
  @Test("loadPersistedChatThreads handles empty history gracefully")
  func test_loadPersistedChatThreads_handlesEmptyHistory() async {
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [])

    let viewModel = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    let originalTabId = viewModel.tab.id
    await viewModel.loadPersistedChatThreads()

    // Should keep the original tab when no persisted threads exist
    #expect(viewModel.tab.id == originalTabId)
  }

  @MainActor
  @Test("loadPersistedChatThreads handles service errors gracefully")
  func test_loadPersistedChatThreads_handlesErrors() async {
    let mockChatHistoryService = MockChatHistoryService()
    mockChatHistoryService.onLoadLastChatThreads = { _, _ in
      throw NSError(domain: "TestError", code: 1, userInfo: nil)
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    let originalTabId = viewModel.tab.id
    await viewModel.loadPersistedChatThreads()

    // Should keep the original tab when loading fails
    #expect(viewModel.tab.id == originalTabId)
  }

  @MainActor
  @Test("handleSelectChatThread loads and switches to selected thread")
  func test_handleSelectChatThread_loadsAndSwitches() async throws {
    let threadId = UUID()
    let testThread = ChatThreadModel(
      id: threadId,
      name: "Selected Thread",
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: Date())

    let mockChatHistoryService = MockChatHistoryService(chatThreads: [testThread])

    let viewModel = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    viewModel.handleShowChatHistory()
    #expect(viewModel.showChatHistory == true)

    let exp = expectation(description: "tab changed")
    let cancellable = viewModel.didSet(\.tab) { tab in
      Task { @MainActor in
        if tab.id == threadId {
          exp.fulfillAtMostOnce()
        }
      }
    }
    viewModel.handleSelectChatThread(id: threadId)

    // Wait for async operation to complete
    try await fulfillment(of: exp)
    _ = cancellable

    #expect(viewModel.tab.id == threadId)
    #expect(viewModel.tab.name == "Selected Thread")
    #expect(viewModel.showChatHistory == false)
  }

  @MainActor
  @Test("handleSelectChatThread handles missing thread gracefully")
  func test_handleSelectChatThread_handlesMissingThread() async throws {
    let mockChatHistoryService = MockChatHistoryService(chatThreads: [])

    let viewModel = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    let originalTabId = viewModel.tab.id
    viewModel.handleShowChatHistory()
    #expect(viewModel.showChatHistory == true)

    let didChangeShowChatHistory = expectation(description: "didChangeShowChatHistory")
    let cancellable = viewModel.didSet(\.showChatHistory, perform: { _ in
      didChangeShowChatHistory.fulfill()
    })

    viewModel.handleSelectChatThread(id: UUID())

    try await fulfillment(of: didChangeShowChatHistory)

    // Should keep original tab and hide chat history
    #expect(viewModel.tab.id == originalTabId)
    #expect(viewModel.showChatHistory == false)
    _ = cancellable
  }

  @MainActor
  @Test("handleSelectChatThread handles service errors gracefully")
  func test_handleSelectChatThread_handlesErrors() async throws {
    let mockChatHistoryService = MockChatHistoryService()
    mockChatHistoryService.onLoadChatThread = { _ in
      throw NSError(domain: "TestError", code: 1, userInfo: nil)
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    let originalTabId = viewModel.tab.id
    viewModel.handleShowChatHistory()
    #expect(viewModel.showChatHistory == true)

    let exp = expectation(description: "tab changed")
    let cancellable = viewModel.didSet(\.showChatHistory) { showChatHistory in
      Task { @MainActor in
        if showChatHistory == false {
          exp.fulfillAtMostOnce()
        }
      }
    }
    viewModel.handleSelectChatThread(id: UUID())

    // Wait for async operation to complete
    try await fulfillment(of: exp)
    _ = cancellable

    // Should keep original tab and hide chat history
    #expect(viewModel.tab.id == originalTabId)
    #expect(viewModel.showChatHistory == false)
  }

  @MainActor
  @Test("handleShowChatHistory sets showChatHistory to true")
  func test_handleShowChatHistory() {
    let viewModel = ChatViewModel()

    #expect(viewModel.showChatHistory == false)

    viewModel.handleShowChatHistory()

    #expect(viewModel.showChatHistory == true)
  }

  @MainActor
  @Test("handleHideChatHistory sets showChatHistory to false")
  func test_handleHideChatHistory() {
    let viewModel = ChatViewModel()
    viewModel.handleShowChatHistory()

    #expect(viewModel.showChatHistory == true)

    viewModel.handleHideChatHistory()

    #expect(viewModel.showChatHistory == false)
  }

  @MainActor
  @Test("chat history integration with multiple threads")
  func test_chatHistoryIntegration_multipleThreads() async {
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

    let viewModel = withDependencies {
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    // Load persisted threads (should load most recent)
    await viewModel.loadPersistedChatThreads()
    #expect(viewModel.tab.id == thread2Id)
    #expect(viewModel.tab.name == "Thread 2")

    // Switch to older thread
    viewModel.handleSelectChatThread(id: thread1Id)
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    #expect(viewModel.tab.id == thread1Id)
    #expect(viewModel.tab.name == "Thread 1")

    // Switch back to newer thread
    viewModel.handleSelectChatThread(id: thread2Id)
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    #expect(viewModel.tab.id == thread2Id)
    #expect(viewModel.tab.name == "Thread 2")
  }

  @MainActor
  @Test("chat history service interactions are called correctly")
  func test_chatHistoryServiceInteractions() async {
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
    await sut.loadPersistedChatThreads()

    // Test loadPersistedChatThreads
    #expect(loadLastChatThreadsCalled.value == true)

    // Test handleSelectChatThread
    sut.handleSelectChatThread(id: threadId)
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    #expect(loadChatThreadCalled.value == true)
    #expect(loadChatThreadId.value == threadId)
  }

  // MARK: - Thread Persistence Tests

  @MainActor
  @Test("setting tab saves thread ID to UserDefaults")
  func test_settingTab_savesThreadIdToUserDefaults() {
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatViewModel()
    }

    let newTab = ChatThreadViewModel()
    viewModel.tab = newTab

    #expect(mockUserDefaults.string(forKey: "lastOpenChatThreadId") == newTab.id.uuidString)
  }

  @MainActor
  @Test("addTab saves new thread ID to UserDefaults")
  func test_addTab_savesNewThreadIdToUserDefaults() {
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatViewModel()
    }

    let originalTabId = viewModel.tab.id
    viewModel.addTab()

    let savedThreadId = mockUserDefaults.string(forKey: "lastOpenChatThreadId")
    #expect(savedThreadId != originalTabId.uuidString)
    #expect(savedThreadId == viewModel.tab.id.uuidString)
  }

  @MainActor
  @Test("loadPersistedChatThreads uses UserDefaults thread ID first")
  func test_loadPersistedChatThreads_usesUserDefaultsFirst() async {
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

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    await viewModel.loadPersistedChatThreads()

    // Should load the saved thread, not the most recent one
    #expect(viewModel.tab.id == savedThreadId)
    #expect(viewModel.tab.name == "Saved Thread")
  }

  @MainActor
  @Test("loadPersistedChatThreads falls back to most recent when UserDefaults has invalid ID")
  func test_loadPersistedChatThreads_fallsBackToMostRecent() async {
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

    let viewModel = await withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      let viewModel = ChatViewModel()
      await viewModel.loadPersistedChatThreads()
      return viewModel
    }

    // Should fall back to most recent thread
    #expect(viewModel.tab.id == recentThreadId)
    #expect(viewModel.tab.name == "Recent Thread")
  }

  @MainActor
  @Test("loadPersistedChatThreads falls back to most recent when saved thread not found")
  func test_loadPersistedChatThreads_fallsBackWhenSavedThreadNotFound() async {
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

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    await viewModel.loadPersistedChatThreads()

    // Should fall back to most recent thread since saved one doesn't exist
    #expect(viewModel.tab.id == recentThreadId)
    #expect(viewModel.tab.name == "Recent Thread")
  }

  @MainActor
  @Test("loadPersistedChatThreads handles missing UserDefaults and uses most recent")
  func test_loadPersistedChatThreads_handlesMissingUserDefaults() async {
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

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    await viewModel.loadPersistedChatThreads()

    // Should use most recent thread
    #expect(viewModel.tab.id == recentThreadId)
    #expect(viewModel.tab.name == "Recent Thread")
  }

  @MainActor
  @Test("tab persistence works end-to-end")
  func test_tabPersistenceEndToEnd() async {
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

    // First instance - should load most recent (thread2)
    let viewModel1 = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    await viewModel1.loadPersistedChatThreads()
    #expect(viewModel1.tab.id == thread2Id)

    // Switch to thread1
    viewModel1.handleSelectChatThread(id: thread1Id)
    try? await Task.sleep(nanoseconds: 100_000_000) // Allow async operation to complete
    #expect(viewModel1.tab.id == thread1Id)

    // Create second instance - should load thread1 (the last saved one)
    let viewModel2 = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.chatHistoryService = mockChatHistoryService
    } operation: {
      ChatViewModel()
    }

    await viewModel2.loadPersistedChatThreads()
    #expect(viewModel2.tab.id == thread1Id)
    #expect(viewModel2.tab.name == "Thread 1")
  }

  @MainActor
  @Test("UserDefaults key constant is correct")
  func test_userDefaultsKeyConstant() {
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatViewModel()
    }

    let newTab = ChatThreadViewModel()
    viewModel.tab = newTab

    // Verify the specific key used
    #expect(mockUserDefaults.string(forKey: "lastOpenChatThreadId") == newTab.id.uuidString)
    #expect(mockUserDefaults.string(forKey: "wrongKey") == nil)
  }

  // MARK: - Summarization Tests

  @MainActor
  @Test("conversation summarization is triggered when token usage exceeds 80% of context size")
  func test_conversationSummarization_triggeredWhenTokensExceedThreshold() async throws {
    let mockLLMService = MockLLMService()
    let summarizeConversationCalled = Atomic(false)
    let expectedSummary = "This is a conversation summary"

    mockLLMService.onSummarizeConversation = { _, _ in
      summarizeConversationCalled.set(to: true)
      return expectedSummary
    }

    mockLLMService.onSendMessage = { _, _, model, _, _, handleUpdateStream in
      let assistantMessage = AssistantMessage("Test response")
      let messageStream = MutableCurrentValueStream<AssistantMessage>(assistantMessage)
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)

      handleUpdateStream(updateStream)

      return SendMessageResponse(
        newMessages: [assistantMessage],
        usageInfo: LLMUsageInfo(
          inputTokens: model.contextSize * 4 / 5, // 80% of context
          outputTokens: 15000, // Total > 80% of context
          idx: 0))
    }

    let viewModel = withAllModelAvailable {
      withDependencies {
        $0.llmService = mockLLMService
      } operation: {
        ChatThreadViewModel()
      }
    }

    viewModel.input.textInput = TextInput([.text("Test message")])
    await viewModel.sendMessage()

    #expect(summarizeConversationCalled.value == true)

    // Verify summary message was added
    let summaryMessages = viewModel.messages.filter { message in
      message.content.contains { content in
        if case .conversationSummary(let summary) = content {
          return summary.text == expectedSummary
        }
        return false
      }
    }
    #expect(summaryMessages.count == 1)
  }

  @MainActor
  @Test("conversation summarization is not triggered when token usage is below threshold")
  func test_conversationSummarization_notTriggeredWhenTokensBelowThreshold() async throws {
    let mockLLMService = MockLLMService()
    let summarizeConversationCalled = Atomic(false)

    mockLLMService.onSummarizeConversation = { _, _ in
      summarizeConversationCalled.set(to: true)
      return "This should not be called"
    }

    mockLLMService.onSendMessage = { _, _, model, _, _, handleUpdateStream in
      let assistantMessage = AssistantMessage("Test response")
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)

      handleUpdateStream(updateStream)

      return SendMessageResponse(
        newMessages: [assistantMessage],
        usageInfo: LLMUsageInfo(
          inputTokens: model.contextSize * 3 / 5, // 60% of context
          outputTokens: 10000, // Total < 80% of context
          idx: 0))
    }

    let viewModel = withAllModelAvailable {
      withDependencies {
        $0.llmService = mockLLMService
      } operation: {
        ChatThreadViewModel()
      }
    }

    viewModel.input.textInput = TextInput([.text("Test message")])
    await viewModel.sendMessage()

    #expect(summarizeConversationCalled.value == false)

    // Verify no summary message was added
    let summaryMessages = viewModel.messages.filter { message in
      message.content.contains { content in
        if case .conversationSummary = content {
          return true
        }
        return false
      }
    }
    #expect(summaryMessages.count == 0)
  }

  @MainActor
  @Test("summarization uses correct model and message history")
  func test_conversationSummarization_usesCorrectParameters() async throws {
    let mockLLMService = MockLLMService()
    let capturedMessageHistory = Atomic<[Schema.Message]?>(nil)
    let capturedModel = Atomic<LLMModel?>(nil)

    mockLLMService.onSummarizeConversation = { messageHistory, model in
      capturedModel.set(to: model)
      capturedMessageHistory.set(to: messageHistory)
      return "Summary"
    }

    mockLLMService.onSendMessage = { _, _, model, _, _, handleUpdateStream in
      let assistantMessage = AssistantMessage("Assistant response")
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)

      handleUpdateStream(updateStream)

      return SendMessageResponse(
        newMessages: [assistantMessage],
        usageInfo: LLMUsageInfo(
          inputTokens: model.contextSize * 4 / 5, // 80% of context
          outputTokens: 15000, // Total > 80% of context
          idx: 0))
    }

    let viewModel = withAllModelAvailable {
      withDependencies {
        $0.llmService = mockLLMService
      } operation: {
        ChatThreadViewModel()
      }
    }

    viewModel.input.textInput = TextInput([.text("User message")])
    await viewModel.sendMessage()

    // Verify correct parameters were passed to summarization
    #expect(capturedModel.value == .gpt)
    #expect(capturedMessageHistory.value?.first?.role == .user)
  }

  @MainActor
  @Test("summarization handles errors gracefully")
  func test_conversationSummarization_handlesErrorsGracefully() async throws {
    let mockLLMService = MockLLMService()

    mockLLMService.onSummarizeConversation = { _, _ in
      throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Summarization failed"])
    }

    mockLLMService.onSendMessage = { _, _, model, _, _, handleUpdateStream in
      let assistantMessage = AssistantMessage("Test response")
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)

      handleUpdateStream(updateStream)

      return SendMessageResponse(
        newMessages: [assistantMessage],
        usageInfo: LLMUsageInfo(
          inputTokens: model.contextSize * 4 / 5, // 80% of context
          outputTokens: 15000, // Total > 80% of context
          idx: 0))
    }

    let viewModel = withAllModelAvailable {
      withDependencies {
        $0.llmService = mockLLMService
      } operation: {
        ChatThreadViewModel()
      }
    }

    let initialMessageCount = viewModel.messages.count

    viewModel.input.textInput = TextInput([.text("Test message")])
    await viewModel.sendMessage()

    // Verify the conversation continues normally despite summarization error
    #expect(viewModel.messages.count > initialMessageCount)

    // Verify no summary message was added due to error
    let summaryMessages = viewModel.messages.filter { message in
      message.content.contains { content in
        if case .conversationSummary = content {
          return true
        }
        return false
      }
    }
    #expect(summaryMessages.count == 0)
  }

  @MainActor
  @Test("message sent during summarization waits for completion and uses summarized context")
  func test_messageDuringSummarization_waitsAndUsesSummarizedContext() async throws {
    let mockLLMService = MockLLMService()
    let summarizationStarted = expectation(description: "Summarization started")
    let secondMessageSentByUser = expectation(description: "Second message sent by user")

    let messagesSent = Atomic<[[Schema.Message]]>([])

    mockLLMService.onSummarizeConversation = { _, _ in
      summarizationStarted.fulfill()
      // Complete summarization after the second message is sent to test concurrent behavior.
      try await fulfillment(of: secondMessageSentByUser)
      return "Conversation summary of previous messages"
    }

    let sendMessageCallCount = Atomic(0)
    mockLLMService.onSendMessage = { messageHistory, _, model, _, _, handleUpdateStream in
      messagesSent.mutate { $0.append(messageHistory) }

      switch sendMessageCallCount.increment() {
      case 1:
        // First message - trigger summarization
        let assistantMessage = AssistantMessage("First response")
        let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)
        handleUpdateStream(updateStream)

        return SendMessageResponse(
          newMessages: [assistantMessage],
          usageInfo: LLMUsageInfo(
            inputTokens: model.contextSize * 4 / 5, // 80% of context - triggers summarization
            outputTokens: 15000,
            idx: 0))

      default:
        // Second message - should only be called after summarization completes
        let assistantMessage = AssistantMessage("Second response")
        let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)
        handleUpdateStream(updateStream)

        return SendMessageResponse(
          newMessages: [assistantMessage],
          usageInfo: nil)
      }
    }

    let viewModel = withAllModelAvailable {
      withDependencies {
        $0.llmService = mockLLMService
      } operation: {
        ChatThreadViewModel()
      }
    }

    // Send first message that will trigger summarization
    viewModel.input.textInput = TextInput([.text("First message")])
    async let firstMessage: Void = viewModel.sendMessage()
    try await fulfillment(of: summarizationStarted)

    viewModel.input.textInput = TextInput([.text("Second message")])
    async let secondMessage: Void = viewModel.sendMessage()
    secondMessageSentByUser.fulfill()

    _ = await firstMessage
    _ = await secondMessage

    let messages = messagesSent.value.map { $0.flatMap { $0.content.map(\.text) } }
    #expect(messages.count == 2)
    #expect(messages == [
      [
        "First message",
      ],
      [
        "Conversation summary of previous messages",
        "Second message",
      ],
    ])
  }

  /// Setup the settings and used default to allow for messages to be sent (there need to be an LLM model configured).
  private func withAllModelAvailable<R>(
    operation: () -> R)
    -> R
  {
    let settingsService = MockSettingsService.allConfigured
    let mockUserDefaults = MockUserDefaults(initialValues: [
      "selectedLLMModel": "gpt-latest",
    ])
    return withDependencies({
      $0.settingsService = settingsService
      $0.userDefaults = mockUserDefaults
    }) {
      operation()
    }
  }
}

extension Schema.MessageContent {
  var text: String? {
    switch self {
    case .textMessage(let value):
      value.text
    default:
      nil
    }
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
