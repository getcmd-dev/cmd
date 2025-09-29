// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatCompletionServiceInterface
import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import LLMServiceInterface
import SwiftTesting
import Testing
@testable import ChatFeature

extension ChatViewModelTests {

  @MainActor
  @Test("client cancellation behavior is properly implemented")
  func test_clientCancellation_behaviorImplemented() async throws {
    // given
    let mockLLMService = MockLLMService()

    let testThreadId = UUID()

    let (threadViewModel, chatViewModel) = withDependencies {
      $0.withAllModelAvailable()
      $0.llmService = mockLLMService
    } operation: {
      let thread = ChatThreadViewModel(id: testThreadId)
      let sut = ChatViewModel()
      sut.tab = thread
      return (thread, sut)
    }

    let isDoneStreaming = expectation(description: "is done streaming")
    let hasReceivedOneStreamedChunk = expectation(description: "has received one streamed chunk")
    let threadChangedFromStreamingToNotStreaming = expectation(description: "thread changed from streaming to not streaming")

    mockLLMService.onSendMessage = { _, _, _, _, _, handleUpdateStream in
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>([])
      handleUpdateStream(updateStream)

      let message = MutableCurrentValueStream<AssistantMessage>(.init(content: []))
      updateStream.update(with: [message])

      let firstTextContent = MutableCurrentValueStream<TextContentMessage>(.init(content: "hello"))
      message.update(with: AssistantMessage(content: [.text(firstTextContent)]))
      firstTextContent.finish()

      try await fulfillment(of: isDoneStreaming)

      let secondTextContent = MutableCurrentValueStream<TextContentMessage>(.init(content: "world"))
      message.update(with: AssistantMessage(content: [.text(firstTextContent), .text(secondTextContent)]))
      secondTextContent.finish()
      message.finish()
      updateStream.finish()
      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    // when
    let chatCompletionInput = ChatCompletionInput(
      threadId: testThreadId.uuidString,
      newUserMessages: ["Test message for client cancellation"],
      modelName: "gpt-5")

    // Handle the chat completion and get the stream
    let receivedEvents = Atomic<[[ChatCompletionServiceInterface.ChatEvent]]>([])
    let task = Task {
      let eventStream = try await chatViewModel.handle(chatCompletion: chatCompletionInput)
      for await event in eventStream {
        let events = receivedEvents.mutate {
          $0.append(event)
          return $0
        }
        if events.flatMap(\.self).count == 1 {
          hasReceivedOneStreamedChunk.fulfill()
        }
      }
    }

    let wasStreaming = Atomic(threadViewModel.isStreamingResponse)
    let cancellable = threadViewModel.observeChanges(to: \.isStreamingResponse) { @Sendable value in
      if wasStreaming.value, !value {
        threadChangedFromStreamingToNotStreaming.fulfill()
      }
      wasStreaming.set(to: value)
    }

    try await fulfillment(of: hasReceivedOneStreamedChunk)
    #expect(threadViewModel.isStreamingResponse)
    task.cancel()
    try await fulfillment(of: threadChangedFromStreamingToNotStreaming)
    #expect(receivedEvents.value.flatMap(\.self).map(\.content) == ["hello\n"])

    // Clean up
    _ = await task.result
    _ = cancellable
  }
}
