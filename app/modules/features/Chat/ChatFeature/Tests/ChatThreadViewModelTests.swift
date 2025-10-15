// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppEventServiceInterface
import ChatFeatureInterface
import ChatFoundation
import Combine
import ConcurrencyFoundation
import Dependencies
import DependenciesTestSupport
import ExtensionEventsInterface
import Foundation
import LLMFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import SharedValuesFoundation
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

private let workspaceURL = URL(fileURLWithPath: "/Users/test/MyProject")
private let fileURL = URL(fileURLWithPath: "/Users/test/MyProject/File.swift")
private let otherFileURL = URL(fileURLWithPath: "/Users/test/MyProject/OtherFile.swift")

// MARK: - ChatThreadViewModelTests

@Suite("ChatThreadViewModelTests", .dependencies {
  $0.withAllModelAvailable()
  $0.appEventHandlerRegistry = MockAppEventHandlerRegistry()
  $0.xcodeObserver = MockXcodeObserver(workspaceURL: workspaceURL, focussedTabURL: fileURL)
})
struct ChatThreadViewModelTests {

  // MARK: - App Event Registry Tests

  @MainActor
  @Test("View model registers handler with app event registry on initialization")
  func viewModelRegistersHandlerWithAppEventRegistry() async throws {
    // Setup
    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    let mockEventRegistry = try #require(appEventHandlerRegistry as? MockAppEventHandlerRegistry)
    let handlerRegistered = Atomic<Bool>(false)

    mockEventRegistry.onRegisterHandler = { _ in
      handlerRegistered.set(to: true)
    }

    // when
    let sut = ChatThreadViewModel()

    // then
    #expect(handlerRegistered.value == true)
    _ = sut // Keep reference
  }

  @MainActor
  @Test("View model handles set_conversation_name command correctly")
  func viewModelHandlesSetConversationNameCommand() async throws {
    // given
    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    let mockEventRegistry = try #require(appEventHandlerRegistry as? MockAppEventHandlerRegistry)
    let registeredHandler = Atomic<(@Sendable (AppEvent) async -> Bool)?>(nil)

    mockEventRegistry.onRegisterHandler = { handler in
      registeredHandler.set(to: handler)
    }

    let sut = ChatThreadViewModel()

    let expectedName = "New Thread Name"
    let nameParams = Schema.NameConversationCommandParams(
      name: expectedName,
      threadId: sut.id.uuidString)
    let extensionRequest = ExtensionRequest(
      command: "set_conversation_name",
      input: nameParams)
    let requestData = try JSONEncoder().encode(extensionRequest)

    let event = ExecuteExtensionRequestEvent(
      command: "set_conversation_name",
      id: UUID().uuidString,
      data: requestData,
      completion: { _ in })

    // when
    let handled = await registeredHandler.value?(event)

    // then
    #expect(handled == true)
    #expect(sut.name == expectedName)
  }

  @MainActor
  @Test("View model ignores set_conversation_name command for different thread")
  func viewModelIgnoresSetConversationNameCommandForDifferentThread() async throws {
    // given
    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    let mockEventRegistry = try #require(appEventHandlerRegistry as? MockAppEventHandlerRegistry)
    let registeredHandler = Atomic<(@Sendable (AppEvent) async -> Bool)?>(nil)

    mockEventRegistry.onRegisterHandler = { handler in
      registeredHandler.set(to: handler)
    }

    let sut = ChatThreadViewModel()

    // Prepare test data with different thread ID
    let nameParams = Schema.NameConversationCommandParams(
      name: "New Thread Name",
      threadId: UUID().uuidString, // Different from sut.id
    )
    let extensionRequest = ExtensionRequest(
      command: "set_conversation_name",
      input: nameParams)
    let requestData = try JSONEncoder().encode(extensionRequest)

    let event = ExecuteExtensionRequestEvent(
      command: "set_conversation_name",
      id: UUID().uuidString,
      data: requestData,
      completion: { _ in })

    // when
    let handled = await registeredHandler.value?(event)

    // then
    #expect(handled == false)
    #expect(sut.name == nil) // Name should remain unchanged
  }

  @MainActor
  @Test("View model ignores non-set_conversation_name commands")
  func viewModelIgnoresNonSetConversationNameCommands() async throws {
    // given
    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    let mockEventRegistry = try #require(appEventHandlerRegistry as? MockAppEventHandlerRegistry)
    let registeredHandler = Atomic<(@Sendable (AppEvent) async -> Bool)?>(nil)

    mockEventRegistry.onRegisterHandler = { handler in
      registeredHandler.set(to: handler)
    }

    let sut = ChatThreadViewModel()

    // Prepare test data with different command
    let event = ExecuteExtensionRequestEvent(
      command: "different_command",
      id: UUID().uuidString,
      data: Data(),
      completion: { _ in })

    // when
    let handled = await registeredHandler.value?(event)

    // then
    #expect(handled == false)
    #expect(sut.name == nil) // Name should remain unchanged
  }

  @MainActor
  @Test("View model handles non-ExecuteExtensionRequestEvent events")
  func viewModelHandlesNonExecuteExtensionRequestEventEvents() async throws {
    // given
    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    let mockEventRegistry = try #require(appEventHandlerRegistry as? MockAppEventHandlerRegistry)
    let registeredHandler = Atomic<(@Sendable (AppEvent) async -> Bool)?>(nil)

    mockEventRegistry.onRegisterHandler = { handler in
      registeredHandler.set(to: handler)
    }

    let sut = ChatThreadViewModel()

    // Create a custom event that is not ExecuteExtensionRequestEvent
    struct CustomEvent: AppEvent { }
    let event = CustomEvent()

    // when
    let handled = await registeredHandler.value?(event)

    // then
    #expect(handled == false)
    _ = sut // Keep reference
  }

  @MainActor
  @Test("receiving messages updates state")
  func test_receivingMessages_updatesState() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

    let testThreadId = UUID()
    let sut = ChatThreadViewModel(id: testThreadId)

    let isDoneStreaming = expectation(description: "is done streaming")
    let hasProcessedFirstMessage = expectation(description: "has processed first message")

    mockLLMService.onSendMessage = { _, _, _, _, _, handleUpdateStream in
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>([])
      handleUpdateStream(updateStream)

      let message = MutableCurrentValueStream<AssistantMessage>(.init(content: []))
      updateStream.update(with: [message])

      let firstTextContent = MutableCurrentValueStream<TextContentMessage>(.init(content: "", deltas: []))
      message.update(with: AssistantMessage(content: [.text(firstTextContent)]))
      firstTextContent.update(with: .init(content: "hello", deltas: ["hello"]))
      firstTextContent.finish()

      try await fulfillment(of: hasProcessedFirstMessage)

      let secondTextContent = MutableCurrentValueStream<TextContentMessage>(.init(content: "", deltas: []))
      message.update(with: AssistantMessage(content: [.text(firstTextContent), .text(secondTextContent)]))
      secondTextContent.update(with: .init(content: "world", deltas: ["world"]))
      secondTextContent.finish()

      message.finish()
      updateStream.finish()

      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    var cancellables = Set<AnyCancellable>()

    let eventsHistory = Atomic<[[String]]>([])
    sut.observeChanges(to: \.events) { value in
      MainActor.assumeIsolated {
        let newValue = value.compactMap { $0.message?.content.asText?.text }
        eventsHistory.mutate { events in
          if events.last != newValue {
            events.append(newValue)
          }
          return events
        }
        if value.count == 3 {
          hasProcessedFirstMessage.fulfillAtMostOnce()
        }
        if value.count == 4 {
          isDoneStreaming.fulfillAtMostOnce()
        }
      }
    }.store(in: &cancellables)

    // when
    sut.input.textInput = .init(NSAttributedString(string: "sup?"))
    await sut.sendMessage()

    // then
    try await fulfillment(of: isDoneStreaming)
    #expect(eventsHistory.value == [["sup?"], ["sup?", "hello"], ["sup?", "hello", "world"]])

    // Clean up
    _ = cancellables
  }

  // MARK: - Focused File Tracking Tests

  @MainActor
  @Test("sendMessage includes focussed file")
  func sendMessageIncludesFocussedFile() async throws {
    // given
    let messagesSent = Atomic<[Schema.Message]>([])
    let hasSentMessages = expectation(description: "has sent messages")

    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    mockLLMService.onSendMessage = { messages, _, _, _, _, _ in
      messagesSent.set(to: messages)
      hasSentMessages.fulfill()
      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    let sut = ChatThreadViewModel()

    // when
    sut.input.textInput = .init(NSAttributedString(string: "How do I fix this?"))
    await sut.sendMessage()
    try await fulfillment(of: hasSentMessages)

    // then
    let sentMessages = messagesSent.value
    #expect(sentMessages.count == 2)
    #expect(sentMessages.map { $0.content.map(\.text) } == [
      ["The file currently focused in the editor is: \(fileURL.path)"],
      ["How do I fix this?"],
    ])
  }

  @MainActor
  @Test("sendMessage includes focussed file only once if it doesn't change")
  func sendMessageIncludesFocussedFileOnlyOnceIfItDoesNotChange() async throws {
    // given
    let messagesSent = Atomic<[Schema.Message]>([])

    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    mockLLMService.onSendMessage = { messages, _, _, _, _, _ in
      messagesSent.set(to: messages)
      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    let sut = ChatThreadViewModel()

    // when
    sut.input.textInput = .init(NSAttributedString(string: "How do I fix this?"))
    await sut.sendMessage()
    sut.input.textInput = .init(NSAttributedString(string: "Thanks"))
    await sut.sendMessage()

    // then
    let sentMessages = messagesSent.value
    #expect(sentMessages.map { $0.content.map(\.text) } == [
      ["The file currently focused in the editor is: \(fileURL.path)"],
      ["How do I fix this?"],
      ["Thanks"],
    ])
  }

  @MainActor
  @Test("sendMessage includes focussed file twice if it changed")
  func sendMessageIncludesFocussedFileTwiceIfItChanged() async throws {
    // given
    let messagesSent = Atomic<[Schema.Message]>([])

    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    mockLLMService.onSendMessage = { messages, _, _, _, _, _ in
      messagesSent.set(to: messages)
      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    @Dependency(\.xcodeObserver) var xcodeObserver
    let mockXcodeObserver = try #require(xcodeObserver as? MockXcodeObserver)

    let sut = ChatThreadViewModel()

    // when
    sut.input.textInput = .init(NSAttributedString(string: "How do I fix this?"))
    await sut.sendMessage()
    let xcodeWorkspaceState = try #require(mockXcodeObserver.state.wrapped?.xcodesState.first?.workspaces.first)
    mockXcodeObserver.mutableStatePublisher.send(.state(
      XcodeState(
        activeApplicationProcessIdentifier: 1,
        previousApplicationProcessIdentifier: nil,
        xcodesState: [
          XcodeAppState(processIdentifier: 1, isActive: true, workspaces: [
            XcodeWorkspaceState(
              axElement: xcodeWorkspaceState.axElement,
              url: workspaceURL,
              editors: [],
              isFocused: true,
              document: nil,
              tabs: [.init(
                fileName: otherFileURL.lastPathComponent,
                isFocused: true,
                knownPath: otherFileURL,
                lastKnownContent: nil)]),
          ]),
        ])))
    sut.input.textInput = .init(NSAttributedString(string: "Thanks"))
    await sut.sendMessage()

    // then
    let sentMessages = messagesSent.value
    #expect(sentMessages.map { $0.content.map(\.text) } == [
      ["The file currently focused in the editor is: \(fileURL.path)"],
      ["How do I fix this?"],
      ["The file currently focused in the editor is: \(otherFileURL.path)"],
      ["Thanks"],
    ])
  }

  // MARK: - Summarization Tests

  @MainActor
  @Test("conversation summarization is triggered when token usage exceeds 80% of context size")
  func conversationSummarizationTriggeredWhenTokensExceedThreshold() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    let summarizeConversationCalled = Atomic(false)
    let expectedSummary = "This is a conversation summary"

    mockLLMService.onSummarizeConversation = { _, _ in
      summarizeConversationCalled.set(to: true)
      return expectedSummary
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

    let sut = ChatThreadViewModel()
    sut.input.textInput = TextInput([.text("Test message")])

    // when
    await sut.sendMessage()

    // then
    #expect(summarizeConversationCalled.value == true)

    let summaryMessages = sut.messages.filter { message in
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
  func conversationSummarizationNotTriggeredWhenTokensBelowThreshold() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
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

    let sut = ChatThreadViewModel()
    sut.input.textInput = TextInput([.text("Test message")])

    // when
    await sut.sendMessage()

    // then
    #expect(summarizeConversationCalled.value == false)

    let summaryMessages = sut.messages.filter { message in
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
  func summarizationUsesCorrectParameters() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    mockLLMService._activeModels.send([.gpt])
    let capturedMessageHistory = Atomic<[Schema.Message]?>(nil)
    let capturedModel = Atomic<AIModel?>(nil)

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

    let sut = ChatThreadViewModel()
    sut.input.textInput = TextInput([.text("User message")])

    // when
    await sut.sendMessage()

    // then
    #expect(capturedModel.value == .gpt)
    #expect(capturedMessageHistory.value?.first?.role == .user)
  }

  @MainActor
  @Test("summarization handles errors gracefully")
  func summarizationHandlesErrorsGracefully() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

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

    let sut = ChatThreadViewModel()
    let initialMessageCount = sut.messages.count
    sut.input.textInput = TextInput([.text("Test message")])

    // when
    await sut.sendMessage()

    // then
    #expect(sut.messages.count > initialMessageCount)

    let summaryMessages = sut.messages.filter { message in
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
  func messageDuringSummarizationWaitsAndUsesSummarizedContext() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
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

    let sut = ChatThreadViewModel()
    sut.input.textInput = TextInput([.text("First message")])

    // when
    async let firstMessage: Void = sut.sendMessage()
    try await fulfillment(of: summarizationStarted)

    sut.input.textInput = TextInput([.text("Second message")])
    async let secondMessage: Void = sut.sendMessage()
    secondMessageSentByUser.fulfill()

    _ = await firstMessage
    _ = await secondMessage

    // then
    let messages = messagesSent.value.map { $0.flatMap { $0.content.map(\.text) } }
    #expect(messages.count == 2)
    #expect(messages == [
      [
        "The file currently focused in the editor is: \(fileURL.path)",
        "First message",
      ],
      [
        "Conversation summary of previous messages",
        "Second message",
      ],
    ])
  }

}
