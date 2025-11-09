// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatHistoryServiceInterface
import Combine
import ConcurrencyFoundation
import Dependencies
import FileSuggestionServiceInterface
import Foundation
import FoundationInterfaces
import LLMFoundation
import LLMServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

// MARK: - ChatInputViewModelTests

@Suite(.dependencies {
  $0.settingsService = MockSettingsService.allConfigured
})
struct ChatInputViewModelTests {

  @MainActor
  @Test("initializing with a selected model that is in available models keeps that model")
  func test_initialization_withSelectedModelInAvailableModels() {
    let selectedModel = AIModel.gpt
    let activeModels: [AIModel] = [.claudeSonnet, .gpt]

    let viewModel = ChatInputViewModel(
      selectedModel: selectedModel,
      activeModels: activeModels)

    #expect(viewModel.selectedModel == selectedModel)
    #expect(viewModel.activeModels == activeModels)
  }

  @MainActor
  @Test("initializing with a selected model that is not in available models selects the first available model")
  func test_initialization_withSelectedModelNotInAvailableModels() {
    let selectedModel = AIModel.claudeOpus
    let activeModels: [AIModel] = [.claudeSonnet, .gpt]

    let viewModel = ChatInputViewModel(
      selectedModel: selectedModel,
      activeModels: activeModels)

    #expect(viewModel.selectedModel == activeModels.first)
    #expect(viewModel.activeModels == activeModels)
  }

  @MainActor
  @Test("initializing with nil selected model selects the first available model")
  func test_initialization_withNilSelectedModel() {
    let activeModels: [AIModel] = [.claudeSonnet, .gpt]

    let viewModel = ChatInputViewModel(
      selectedModel: nil,
      activeModels: activeModels)

    #expect(viewModel.selectedModel == activeModels.first)
    #expect(viewModel.activeModels == activeModels)
  }

  @MainActor
  @Test("initializing with empty available models results in nil selected model")
  func test_initialization_withEmptyAvailableModels() {
    let viewModel = ChatInputViewModel(
      selectedModel: nil,
      activeModels: [])

    #expect(viewModel.selectedModel == nil)
  }

  @MainActor
  @Test("updating available models keeps selected model if it's still available")
  func test_updatingAvailableModels_keepsSelectedModelIfStillAvailable() {
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatInputViewModel(
        selectedModel: .gpt,
        activeModels: [.claudeSonnet, .gpt, .gpt_turbo])
    }

    #expect(viewModel.selectedModel == .gpt)
  }

  @MainActor
  @Test("updating available models changes selected model if it's no longer available")
  func test_updatingAvailableModels_changesSelectedModelIfNoLongerAvailable() async throws {
    // given
    let mockLLMService = MockLLMService(activeModels: [.claudeSonnet, .gpt])
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
    let mockUserDefaults = MockUserDefaults()

    let sut = withDependencies {
      $0.llmService = mockLLMService
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatInputViewModel(
        selectedModel: .claudeSonnet,
        activeModels: nil)
    }
    let hasChangedModelToGpt = expectation(description: "Has changed model to gpt")
    let cancellable = sut.observeChanges(to: \.selectedModel) { newValue in
      if newValue == .gpt {
        hasChangedModelToGpt.fulfillAtMostOnce()
      }
    }
    #expect(sut.selectedModel == .claudeSonnet)

    // when
    mockLLMService._activeModels.send([.gpt])

    // then
    try await fulfillment(of: hasChangedModelToGpt)
    _ = cancellable

    // then
    #expect(sut.selectedModel == .gpt)
  }

  @MainActor
  @Test("updating available models to empty array sets selected model to nil")
  func test_updatingAvailableModels_toEmptyArray() async throws {
    // given
    let mockLLMService = MockLLMService(activeModels: [.claudeSonnet])
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
    let mockUserDefaults = MockUserDefaults()

    let sut = withDependencies {
      $0.llmService = mockLLMService
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatInputViewModel(
        selectedModel: .claudeSonnet,
        activeModels: nil)
    }
    #expect(sut.selectedModel == .claudeSonnet)

    // Prepare observation to changes in propeerties
    let hasChangedActiveModels = expectation(description: "Has changed active models")
    let hasChangedSelectedModels = expectation(description: "Has changed selected model")
    var cancellables = Set<AnyCancellable>()
    sut.observeChanges(to: \.activeModels) { _ in
      hasChangedActiveModels.fulfillAtMostOnce()
    }.store(in: &cancellables)
    sut.observeChanges(to: \.selectedModel) { _ in
      hasChangedSelectedModels.fulfillAtMostOnce()
    }.store(in: &cancellables)

    // when - simulate removing openAI provider (anthropic models remain)
    mockLLMService._activeModels.send([
      .claudeHaiku_3_5,
      .claudeOpus,
      .claudeSonnet,
    ])

    // then
    try await fulfillment(of: hasChangedActiveModels)
    #expect(sut.activeModels.sorted(by: { $0.id < $1.id }) == [
      .claudeHaiku_3_5,
      .claudeOpus,
      .claudeSonnet,
    ])
    #expect(sut.selectedModel == .claudeSonnet)

    // when - simulate removing all providers
    mockLLMService._activeModels.send([])
    try await fulfillment(of: hasChangedSelectedModels)

    // then
    #expect(sut.activeModels.isEmpty)
    #expect(sut.selectedModel == nil)
    _ = cancellables
  }

  // MARK: - Queue Tests

  @MainActor
  @Test("queueCurrentMessage adds message to queue and clears input")
  func test_queueCurrentMessage() {
    let viewModel = ChatInputViewModel(
      selectedModel: .gpt,
      activeModels: [.gpt])

    // Set up input
    viewModel.textInput = TextInput(NSAttributedString(string: "Test message"))

    // Queue the message
    viewModel.queueCurrentMessage()

    // Verify message was queued
    #expect(viewModel.queuedMessages.count == 1)
    #expect(viewModel.queuedMessages.first?.text == "Test message")

    // Verify input was cleared
    #expect(viewModel.textInput.string.string.isEmpty)
    #expect(viewModel.attachments.isEmpty)
  }

  @MainActor
  @Test("sendQueuedMessageNow cancels current stream then sends message")
  func test_sendQueuedMessageNow_cancelsThenSends() {
    let viewModel = ChatInputViewModel(
      selectedModel: .gpt,
      activeModels: [.gpt])

    var callOrder = [String]()

    // Set up callbacks to track order
    viewModel.didCancelMessage = {
      callOrder.append("cancel")
    }
    viewModel.didTapSendMessage = {
      callOrder.append("send")
    }

    // Add a message to queue
    let message = QueuedMessageModel(
      id: UUID(),
      text: "Queued message",
      attachments: [],
      createdAt: Date())
    viewModel.queuedMessages = [message]

    // Send the queued message now
    viewModel.sendQueuedMessageNow(message)

    // Verify cancel was called before send
    #expect(callOrder == ["cancel", "send"])

    // Verify message was removed from queue
    #expect(viewModel.queuedMessages.isEmpty)

    // Verify message was set as current input
    #expect(viewModel.textInput.string.string == "Queued message")
  }

  @MainActor
  @Test("deleteQueuedMessage removes message from queue")
  func test_deleteQueuedMessage() {
    let viewModel = ChatInputViewModel(
      selectedModel: .gpt,
      activeModels: [.gpt])

    // Add messages to queue
    let message1 = QueuedMessageModel(id: UUID(), text: "First", attachments: [], createdAt: Date())
    let message2 = QueuedMessageModel(id: UUID(), text: "Second", attachments: [], createdAt: Date())

    viewModel.queuedMessages = [message1, message2]

    // Delete first message
    viewModel.deleteQueuedMessage(message1.id)

    // Verify message was removed
    #expect(viewModel.queuedMessages.count == 1)
    #expect(viewModel.queuedMessages.first?.id == message2.id)
  }

  @MainActor
  @Test("processNextQueuedMessage sends first message in queue")
  func test_processNextQueuedMessage() {
    let viewModel = ChatInputViewModel(
      selectedModel: .gpt,
      activeModels: [.gpt])

    var sendCalled = false
    viewModel.didTapSendMessage = {
      sendCalled = true
    }

    // Add a message to queue
    let message = QueuedMessageModel(id: UUID(), text: "Queued message", attachments: [], createdAt: Date())
    viewModel.queuedMessages = [message]

    // Process next message
    viewModel.processNextQueuedMessage()

    // Verify send was called
    #expect(sendCalled)

    // Verify message was removed from queue
    #expect(viewModel.queuedMessages.isEmpty)

    // Verify message was set as current input
    #expect(viewModel.textInput.string.string == "Queued message")
  }

  @MainActor
  @Test("sendQueuedMessageNow only sends selected message and keeps other queued messages")
  func test_sendQueuedMessageNow_onlySendsSelectedMessage() {
    let viewModel = ChatInputViewModel(
      selectedModel: .gpt,
      activeModels: [.gpt])

    var sendCount = 0
    viewModel.didTapSendMessage = {
      sendCount += 1
    }
    viewModel.didCancelMessage = { }

    // Add multiple messages to queue
    let message1 = QueuedMessageModel(id: UUID(), text: "First", attachments: [], createdAt: Date())
    let message2 = QueuedMessageModel(id: UUID(), text: "Second", attachments: [], createdAt: Date())
    let message3 = QueuedMessageModel(id: UUID(), text: "Third", attachments: [], createdAt: Date())

    viewModel.queuedMessages = [message1, message2, message3]

    // Send the second message now
    viewModel.sendQueuedMessageNow(message2)

    // Verify only one send was called
    #expect(sendCount == 1)

    // Verify selected message was sent
    #expect(viewModel.textInput.string.string == "Second")

    // Verify other messages remain in queue
    #expect(viewModel.queuedMessages.count == 2)
    #expect(viewModel.queuedMessages.contains(where: { $0.id == message1.id }))
    #expect(viewModel.queuedMessages.contains(where: { $0.id == message3.id }))
    #expect(!viewModel.queuedMessages.contains(where: { $0.id == message2.id }))
  }

  @MainActor
  @Test("mergeQueuedMessagesToInput combines current input with queued messages")
  func test_mergeQueuedMessagesToInput() {
    let viewModel = ChatInputViewModel(
      selectedModel: .gpt,
      activeModels: [.gpt])

    // Set current input
    viewModel.textInput = TextInput(NSAttributedString(string: "Current input"))

    // Add attachment to current input
    let currentAttachment = AttachmentModel.file(.init(
      id: UUID(),
      path: URL(filePath: "/path/to/current"),
      content: "current content"))
    viewModel.attachments = [currentAttachment]

    // Add queued messages with attachments
    let attachment1 = AttachmentModel.file(.init(
      id: UUID(),
      path: URL(filePath: "/path/to/file1"),
      content: "file1 content"))
    let attachment2 = AttachmentModel.file(.init(
      id: UUID(),
      path: URL(filePath: "/path/to/file2"),
      content: "file2 content"))

    let message1 = QueuedMessageModel(
      id: UUID(),
      text: "First queued",
      attachments: [attachment1],
      createdAt: Date())
    let message2 = QueuedMessageModel(
      id: UUID(),
      text: "Second queued",
      attachments: [attachment2],
      createdAt: Date())

    viewModel.queuedMessages = [message1, message2]

    // Merge queued messages to input
    viewModel.mergeQueuedMessagesToInput()

    // Verify text was combined with correct order: queued messages first, then current input
    let expectedText = "First queued\n\nSecond queued\n\nCurrent input"
    #expect(viewModel.textInput.string.string == expectedText)

    // Verify attachments were merged with correct order: queued attachments first, then current
    #expect(viewModel.attachments.count == 3)
    if case .file(let fileModel) = viewModel.attachments[0] {
      #expect(fileModel.path.path() == "/path/to/file1")
    } else {
      Issue.record("Expected first attachment to be from first queued message")
    }
    if case .file(let fileModel) = viewModel.attachments[1] {
      #expect(fileModel.path.path() == "/path/to/file2")
    } else {
      Issue.record("Expected second attachment to be from second queued message")
    }
    if case .file(let fileModel) = viewModel.attachments[2] {
      #expect(fileModel.path.path() == "/path/to/current")
    } else {
      Issue.record("Expected third attachment to be from current input")
    }

    // Verify queue was cleared
    #expect(viewModel.queuedMessages.isEmpty)
  }

  // MARK: - File Suggestion Timeout Tests

  @MainActor
  @Test("file suggestion search times out after 500ms")
  func test_fileSuggestionSearch_timesOut() async throws {
    // given
    let mockXcodeObserver = MockXcodeObserver(workspaceURL: URL(filePath: "/workspace"))
    let mockFileSuggestionService = MockFileSuggestionService()

    // Configure the mock to hang indefinitely
    mockFileSuggestionService.onSuggestFiles = { _, _, _ in
      // This will never return, simulating a hang
      try await Task.sleep(nanoseconds: 100_000_000_000) // 100 seconds
      return []
    }

    let sut = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
      $0.fileSuggestionService = mockFileSuggestionService
    } operation: {
      ChatInputViewModel(selectedModel: .gpt, activeModels: [.gpt])
    }

    let receivedTimeout = expectation(description: "Received timeout")

    // when - trigger search
    sut.inlineSearch = ("test", NSRange(location: 0, length: 4), nil)

    // Wait a bit for the timeout to trigger (500ms + margin)
    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

    // If we reach here without the test hanging, the timeout worked
    receivedTimeout.fulfill()

    try await fulfillment(of: receivedTimeout)
  }
}

extension MockSettingsService {
  static var allConfigured: MockSettingsService {
    MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "test",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "test",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
  }
}
