// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import ChatCompletionService

enum DefaultChatCompletionServiceHelpersTests {
  struct ThreadIdTests {
    @Test
    func test_findsThreadIdInText() {
      // Given
      let uuid = UUID().uuidString
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .system(.init(content: .textContent("Be a good assistant"))),
        .user(.init(content: .string("Can you help me"))),
        .assistant(.init(content: .textContent("""
          thread_id: \(uuid)

          Sure thing
          """))),
      ]
      // Test
      #expect(messages.threadId == uuid)
    }

    @Test
    func test_findsThreadIdInContentParts() {
      // Given
      let uuid = UUID().uuidString
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .system(.init(content: .textContent("Be a good assistant"))),
        .user(.init(content: .string("Can you help me"))),
        .assistant(.init(content: .contentParts([
          .text(.init(text: """
            thread_id: \(uuid)

            Sure thing
            """)),
        ]))),
      ]
      // Test
      #expect(messages.threadId == uuid)
    }

    @Test
    func test_returnsNilWhenMissing() {
      // Given
      let uuid = UUID().uuidString
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .system(.init(content: .textContent("Be a good assistant"))),
        .user(.init(content: .string("Can you help me"))),
      ]
      // Test
      #expect(messages.threadId == nil)
    }

    @Test
    func test_ignoresDataInUserMessage() {
      // Given
      let uuid = UUID().uuidString
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .system(.init(content: .textContent("Be a good assistant"))),
        .user(.init(content: .string("""
          thread_id: \(uuid)

          Can you help me?
          """))),
        .assistant(.init(content: .textContent("""
          Sure thing
          """))),
      ]
      // Test
      #expect(messages.threadId == nil)
    }
  }

  struct NewUserMessagesTests {
    @Test
    func test_returnsUserMessagesAfterLastAssistant() {
      // Given
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .system(.init(content: .textContent("Be a good assistant"))),
        .user(.init(content: .string("First user message"))),
        .assistant(.init(content: .textContent("Assistant response"))),
        .user(.init(content: .string("Second user message"))),
        .user(.init(content: .string("Third user message"))),
      ]

      // Test
      let newUserMessages = messages.newUserMessages
      #expect(newUserMessages.count == 2)
      #expect(newUserMessages[0].content.string == "Second user message")
      #expect(newUserMessages[1].content.string == "Third user message")
    }

    @Test
    func test_returnsAllUserMessagesWhenNoAssistant() {
      // Given
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .system(.init(content: .textContent("Be a good assistant"))),
        .user(.init(content: .string("First user message"))),
        .user(.init(content: .string("Second user message"))),
      ]

      // Test
      let newUserMessages = messages.newUserMessages
      #expect(newUserMessages.count == 2)
      #expect(newUserMessages[0].content.string == "First user message")
      #expect(newUserMessages[1].content.string == "Second user message")
    }

    @Test
    func test_returnsEmptyWhenLastMessageIsAssistant() {
      // Given
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .system(.init(content: .textContent("Be a good assistant"))),
        .user(.init(content: .string("User message"))),
        .assistant(.init(content: .textContent("Assistant response"))),
      ]

      // Test
      let newUserMessages = messages.newUserMessages
      #expect(newUserMessages.isEmpty)
    }

    @Test
    func test_resetsAfterEachAssistantMessage() {
      // Given
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .user(.init(content: .string("First user message"))),
        .assistant(.init(content: .textContent("First assistant response"))),
        .user(.init(content: .string("Second user message"))),
        .user(.init(content: .string("Third user message"))),
        .assistant(.init(content: .textContent("Second assistant response"))),
        .user(.init(content: .string("Fourth user message"))),
      ]

      // Test
      let newUserMessages = messages.newUserMessages
      #expect(newUserMessages.count == 1)
      #expect(newUserMessages[0].content.string == "Fourth user message")
    }

    @Test
    func test_ignoresSystemMessages() {
      // Given
      let messages: [ChatQuery.ChatCompletionMessageParam] = [
        .assistant(.init(content: .textContent("Assistant response"))),
        .system(.init(content: .textContent("System message"))),
        .user(.init(content: .string("User message"))),
      ]

      // Test
      let newUserMessages = messages.newUserMessages
      #expect(newUserMessages.count == 1)
      #expect(newUserMessages[0].content.string == "User message")
    }

    @Test
    func test_returnsEmptyForEmptyArray() {
      // Given
      let messages = [ChatQuery.ChatCompletionMessageParam]()

      // Test
      let newUserMessages = messages.newUserMessages
      #expect(newUserMessages.isEmpty)
    }
  }
}
