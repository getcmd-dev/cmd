// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import ChatFoundation
import ChatHistoryServiceInterface
import ChatServiceInterface
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
  $0.xcodeObserver = MockXcodeObserver(workspaceURL: workspaceURL, focussedTabURL: fileURL)
})
struct ChatThreadViewModelTests {

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
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

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
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))
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
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))
    try? await Task.sleep(for: .milliseconds(10)) // Let async send complete
    sut.input.textInput = .init(NSAttributedString(string: "Thanks"))
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))
    try? await Task.sleep(for: .milliseconds(10)) // Let async send complete

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
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))
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
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

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
      return SummarizeConversationResponse(summary: expectedSummary, usageInfo: nil)
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
          cachedInputTokens: 0,
          idx: 0))
    }

    let sut = ChatThreadViewModel()
    sut.input.textInput = TextInput([.text("Test message")])

    // when
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

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
      return SummarizeConversationResponse(summary: "This should not be called", usageInfo: nil)
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
          cachedInputTokens: 0,
          idx: 0))
    }

    let sut = ChatThreadViewModel()
    sut.input.textInput = TextInput([.text("Test message")])

    // when
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

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
    let summarizationCalled = expectation(description: "Summarization called")

    mockLLMService.onSummarizeConversation = { messageHistory, model in
      capturedModel.set(to: model)
      capturedMessageHistory.set(to: messageHistory)
      summarizationCalled.fulfill()
      return SummarizeConversationResponse(summary: "Summary", usageInfo: nil)
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
          cachedInputTokens: 0,
          idx: 0))
    }

    let sut = ChatThreadViewModel()
    sut.input.textInput = TextInput([.text("User message")])

    // when
    sut.input.sendMessage()
    try await fulfillment(of: summarizationCalled)

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
          cachedInputTokens: 0,
          idx: 0))
    }

    let sut = ChatThreadViewModel()
    let initialMessageCount = sut.messages.count
    sut.input.textInput = TextInput([.text("Test message")])

    // when
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

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
      return SummarizeConversationResponse(summary: "Conversation summary of previous messages", usageInfo: nil)
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
            cachedInputTokens: 0,
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
    async let firstMessage: Void = sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))
    try await fulfillment(of: summarizationStarted)

    sut.input.textInput = TextInput([.text("Second message")])
    async let secondMessage: Void = sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))
    secondMessageSentByUser.fulfill()

    _ = await firstMessage
    _ = await secondMessage
    try? await Task.sleep(for: .milliseconds(50)) // Extra time for summarization

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

  // MARK: - Token Usage Tests

  @MainActor
  @Test("latestTokenUsage is initialized from events when thread is deserialized")
  func latestTokenUsageInitializedFromEvents() async throws {
    // given
    let tokenUsageEvent1 = TokenUsageEvent(
      inputTokens: 100,
      cachedInputTokens: 50,
      outputTokens: 30)
    let tokenUsageEvent2 = TokenUsageEvent(
      inputTokens: 200,
      cachedInputTokens: 100,
      outputTokens: 50)

    let events: [ChatEvent] = [
      .message(.init(content: .text(.init(projectRoot: nil, text: "Hello", attachments: [])), role: .user)),
      .tokenUsage(tokenUsageEvent1),
      .message(.init(content: .text(.init(projectRoot: nil, text: "World", attachments: [])), role: .assistant)),
      .tokenUsage(tokenUsageEvent2),
    ]

    // when
    let sut = ChatThreadViewModel(
      id: UUID(),
      name: "Test Thread",
      messages: [],
      events: events)

    // then
    #expect(sut.latestTokenUsage?.id == tokenUsageEvent2.id)
    #expect(sut.latestTokenUsage?.inputTokens == 200)
    #expect(sut.latestTokenUsage?.cachedInputTokens == 100)
    #expect(sut.latestTokenUsage?.outputTokens == 50)
  }

  @MainActor
  @Test("latestTokenUsage is nil when no token usage events exist")
  func latestTokenUsageNilWhenNoEvents() async throws {
    // given
    let events: [ChatEvent] = [
      .message(.init(content: .text(.init(projectRoot: nil, text: "Hello", attachments: [])), role: .user)),
      .message(.init(content: .text(.init(projectRoot: nil, text: "World", attachments: [])), role: .assistant)),
    ]

    // when
    let sut = ChatThreadViewModel(
      id: UUID(),
      name: "Test Thread",
      messages: [],
      events: events)

    // then
    #expect(sut.latestTokenUsage == nil)
  }

  @MainActor
  @Test("token usage event is added when receiving usageInfo from sendMessage")
  func tokenUsageEventAddedWhenReceivingUsageInfo() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

    let usageInfo = LLMUsageInfo(
      inputTokens: 150,
      outputTokens: 75,
      cachedInputTokens: 50,
      idx: 0)

    mockLLMService.onSendMessage = { _, _, _, _, _, handleUpdateStream in
      let assistantMessage = AssistantMessage("Test response")
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)
      handleUpdateStream(updateStream)

      return SendMessageResponse(
        newMessages: [assistantMessage],
        usageInfo: usageInfo)
    }

    let sut = ChatThreadViewModel()
    sut.input.textInput = TextInput([.text("Test message")])

    // when
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

    // then
    let tokenUsageEvents = sut.events.compactMap(\.tokenUsage)
    #expect(tokenUsageEvents.count == 1)

    let tokenUsage = try #require(tokenUsageEvents.first)
    #expect(tokenUsage.inputTokens == 150)
    #expect(tokenUsage.cachedInputTokens == 50)
    #expect(tokenUsage.outputTokens == 75)
  }

  @MainActor
  @Test("latestTokenUsage is updated when receiving usageInfo from sendMessage")
  func latestTokenUsageUpdatedWhenReceivingUsageInfo() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

    let usageInfo = LLMUsageInfo(
      inputTokens: 200,
      outputTokens: 50,
      cachedInputTokens: 100,
      idx: 0)

    mockLLMService.onSendMessage = { _, _, _, _, _, handleUpdateStream in
      let assistantMessage = AssistantMessage("Test response")
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)
      handleUpdateStream(updateStream)

      return SendMessageResponse(
        newMessages: [assistantMessage],
        usageInfo: usageInfo)
    }

    let sut = ChatThreadViewModel()
    #expect(sut.latestTokenUsage == nil)

    sut.input.textInput = TextInput([.text("Test message")])

    // when
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

    // then
    let latestTokenUsage = try #require(sut.latestTokenUsage)
    #expect(latestTokenUsage.inputTokens == 200)
    #expect(latestTokenUsage.cachedInputTokens == 100)
    #expect(latestTokenUsage.outputTokens == 50)
  }

  @MainActor
  @Test("multiple messages update latestTokenUsage to most recent")
  func multipleMessagesUpdateLatestTokenUsage() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

    let firstUsageInfo = LLMUsageInfo(
      inputTokens: 100,
      outputTokens: 30,
      cachedInputTokens: 20,
      idx: 0)

    let secondUsageInfo = LLMUsageInfo(
      inputTokens: 200,
      outputTokens: 60,
      cachedInputTokens: 50,
      idx: 0)

    let callCount = Atomic(0)
    mockLLMService.onSendMessage = { _, _, _, _, _, handleUpdateStream in
      let count = callCount.increment()
      let assistantMessage = AssistantMessage("Test response \(count)")
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)
      handleUpdateStream(updateStream)

      return SendMessageResponse(
        newMessages: [assistantMessage],
        usageInfo: count == 1 ? firstUsageInfo : secondUsageInfo)
    }

    let sut = ChatThreadViewModel()

    // when
    sut.input.textInput = TextInput([.text("First message")])
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

    sut.input.textInput = TextInput([.text("Second message")])
    sut.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))

    // then
    let tokenUsageEvents = sut.events.compactMap(\.tokenUsage)
    #expect(tokenUsageEvents.count == 2)

    let latestTokenUsage = try #require(sut.latestTokenUsage)
    #expect(latestTokenUsage.inputTokens == 200)
    #expect(latestTokenUsage.cachedInputTokens == 50)
    #expect(latestTokenUsage.outputTokens == 60)
  }

  @MainActor
  @Test("compactConversation creates token usage event with output tokens only")
  func compactConversationCreatesTokenUsageEvent() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    mockLLMService._activeModels.send([.gpt])

    let summarizationUsageInfo = LLMUsageInfo(
      inputTokens: 1000,
      outputTokens: 150,
      cachedInputTokens: 200,
      idx: 0)

    mockLLMService.onSummarizeConversation = { _, _ in
      SummarizeConversationResponse(
        summary: "Conversation summary",
        usageInfo: summarizationUsageInfo)
    }

    let sut = ChatThreadViewModel()
    let initialEventCount = sut.events.count

    // when
    await sut.compactConversation()

    // then
    let tokenUsageEvents = sut.events.compactMap(\.tokenUsage)
    #expect(tokenUsageEvents.count == 1)

    let tokenUsage = try #require(tokenUsageEvents.first)
    // For compaction, only output tokens are counted in the next turn
    #expect(tokenUsage.inputTokens == 0)
    #expect(tokenUsage.cachedInputTokens == 0)
    #expect(tokenUsage.outputTokens == 150)

    // Verify latestTokenUsage is updated
    let latestTokenUsage = try #require(sut.latestTokenUsage)
    #expect(latestTokenUsage.id == tokenUsage.id)
  }

  @MainActor
  @Test("compactConversation does not create token usage event when usageInfo is nil")
  func compactConversationNoTokenUsageWhenUsageInfoNil() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    mockLLMService._activeModels.send([.gpt])

    mockLLMService.onSummarizeConversation = { _, _ in
      SummarizeConversationResponse(
        summary: "Conversation summary",
        usageInfo: nil)
    }

    let sut = ChatThreadViewModel()

    // when
    await sut.compactConversation()

    // then
    let tokenUsageEvents = sut.events.compactMap(\.tokenUsage)
    #expect(tokenUsageEvents.count == 0)
    #expect(sut.latestTokenUsage == nil)
  }

  // MARK: - ChatService Retention Integration Tests

  @MainActor
  @Test("view model is retained via ChatService during streaming to prevent deallocation")
  func viewModelIsRetainedDuringStreaming() async throws {
    // given
    @Dependency(\.llmService) var llmService
    @Dependency(\.chatService) var chatService
    let mockLLMService = try #require(llmService as? MockLLMService)

    let streamingStarted = expectation(description: "Streaming started")
    let streamingCanComplete = expectation(description: "Streaming can complete")

    let viewModelId = UUID()
    nonisolated(unsafe) weak var weakViewModel: ChatThreadViewModel?

    mockLLMService.onSendMessage = { _, _, _, _, _, handleUpdateStream in
      let assistantMessage = AssistantMessage("Test response")
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>(assistantMessage)

      handleUpdateStream(updateStream)
      streamingStarted.fulfill()

      try await fulfillment(of: streamingCanComplete)

      return SendMessageResponse(
        newMessages: [assistantMessage],
        usageInfo: nil)
    }

    // when
    let viewModel = Atomic<ChatThreadViewModel?>(ChatThreadViewModel(id: viewModelId))
    weakViewModel = viewModel.value
    viewModel.value?.input.textInput = TextInput([.text("Test message")])

    async let sendTask: Void? = viewModel.value?.input.sendMessage()
    try? await Task.sleep(for: .milliseconds(10))
    try await fulfillment(of: streamingStarted)
    viewModel.set(to: nil)

    // Verify the view model is retained while streaming even if we drop our strong reference
    #expect(weakViewModel != nil)

    // Allow streaming to complete
    streamingCanComplete.fulfill()

    await sendTask
    // TODO: test for de-allocation here
  }

}
