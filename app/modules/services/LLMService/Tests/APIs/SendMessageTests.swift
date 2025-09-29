// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import LLMFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
import ToolFoundation

@testable import LLMService

// MARK: - SendMessageTests

final class SendMessageTests {
  @Test("SendMessage receives text chunks")
  func test_sendMessage() async throws {
    let chunksReceived = expectation(description: "All chunk received")
    let messagesUpdatesReceived = expectation(description: "All messages update received")
    let firstMessageUpdatesReceived = expectation(description: "All updates for the first message received")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "hi",
          "idx": 0
        }
        """.utf8Data)
      sendChunk?("""
        {
          "type": "text_delta",
          "text": " what can I do?",
          "idx": 1
        }
        """.utf8Data)
      return okServerResponse
    }
    let updatingMessages = try await sut.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [])

    let messagesUpdateCount = Atomic(0)
    let firstMessageUpdateCount = Atomic(0)
    let contentUpdateCount = Atomic(0)
    Task {
      for await messages in updatingMessages.futureUpdates {
        let count = messagesUpdateCount.increment()
        if count == 1 {
          // First update has one message
          #expect(messages.count == 1)

          let updatingMessage = try #require(messages.first)

          for await message in updatingMessage.futureUpdates {
            let firstCount = firstMessageUpdateCount.increment()
            if firstCount == 1 {
              // First update has one piece of text content
              #expect(message.content.count == 1)
              let updatingTextContent = try #require(message.content.first?.asText)

              for await textContent in updatingTextContent.futureUpdates {
                let contentCount = contentUpdateCount.increment()
                if contentCount == 1 {
                  #expect(textContent.content == "hi what can I do?")
                  #expect(textContent.deltas == ["hi", " what can I do?"])
                }
              }
              chunksReceived.fulfill()
            }
          }
          firstMessageUpdatesReceived.fulfill()
        }
      }
      messagesUpdatesReceived.fulfill()
    }

    try await fulfillment(of: [messagesUpdatesReceived, firstMessageUpdatesReceived, chunksReceived])
    #expect(messagesUpdateCount.value == 1)
    #expect(firstMessageUpdateCount.value == 1)
    #expect(contentUpdateCount.value == 1)
  }

  @Test("SendMessage with long message history")
  func test_sendMessage_withLongMessageHistory() async throws {
    let requestResponded = expectation(description: "The request was responded to")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "sure",
          "idx": 0
        }
        """.utf8Data)
      requestResponded.fulfill()
      return okServerResponse
    }
    let messages = try await sut.sendMessage(
      messageHistory: [
        .init(role: .user, content: [.textMessage(.init(text: "hello"))]),
        .init(role: .user, content: [.textMessage(.init(text: "sup?"))]),
        .init(role: .user, content: [.textMessage(.init(text: "can you help me?"))]),
        .init(role: .assistant, content: [.textMessage(.init(text: "sure"))]),
        .init(role: .user, content: [.textMessage(.init(text: "I need coffee"))]),
      ],
      tools: []).lastValue

    #expect(messages.count == 1)
    let firstMessage = try await (#require(messages.first)).lastValue
    let firstMessageContent = firstMessage.content
    #expect(firstMessageContent.count == 1)
    let textContent = try await (#require(firstMessageContent.first?.asText)).lastValue
    #expect(textContent.content == "sure")

    try await fulfillment(of: [requestResponded])
  }

  @Test("SendMessage with tool use")
  func test_sendMessage_withToolUse() async throws {
    let requestResponded = expectation(description: "The request was responded to")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)

    let requestCount = Atomic(0)
    server.onPostRequest = { _, data, sendChunk in
      if requestCount.increment() == 1 {
        sendChunk?("""
          {
            "type": "text_delta",
            "text": "hi",
            "idx": 0
          }
          """.utf8Data)
        sendChunk?("""
          {
            "type": "tool_call",
            "toolName": "TestTool",
            "input": {},
            "toolUseId": "123",
            "idx": 1
          }
          """.utf8Data)
        return okServerResponse
      } else {
        data.expectToMatch(
          """
          {
            "messages":[
              {"role":"user","content":[{"type":"text","text":"hello"}]},
              {"role":"assistant","content":[
                {"type":"text","text":"hi"},
                {"type":"tool_call","toolUseId":"123","toolName":"TestTool","input":{},"idx" : 0}
              ]},
              {"role":"tool","content":[{"toolUseId":"123","toolName":"TestTool","type":"tool_result","result":{"type":"tool_result_success","success":"test_result"}}]}
            ],
            "model" : "claude-sonnet-4-5-20250929",
            "enableReasoning": false,
            "provider" : {
              "name" : "anthropic",
              "settings" : { "apiKey" : "anthropic-key" }
            },
            "tools":[{"inputSchema":{},"name":"TestTool","description":"tool for testing"}],
            "projectRoot" : "/path/to/root",
            "threadId" : "mock-thread-id"
          }
          """,
          ignoring: "system")
        sendChunk?("""
          {
            "type": "text_delta",
            "text": "got it!",
            "idx": 0
          }
          """.utf8Data)
        requestResponded.fulfill()
        return okServerResponse
      }
    }

    let messages = try await sut.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [TestTool<EmptyObject, String>(output: "test_result")]).lastValue
    #expect(messages.count == 2)

    let firstMessage = try await (#require(messages.first)).lastValue
    let firstMessageContent = firstMessage.content
    #expect(firstMessageContent.count == 2)
    #expect(firstMessageContent.first?.asText?.content == "hi")
    #expect(firstMessageContent.last?.asToolUseRequest != nil)

    let secondMessage = try await (#require(messages.last)).lastValue
    let secondMessageContent = secondMessage.content
    #expect(secondMessageContent.count == 1)
    #expect(secondMessageContent.first?.asText?.content == "got it!")

    try await fulfillment(of: [requestResponded])
  }

  @Test("SendMessage with failed tool use")
  func test_sendMessage_withFailedToolUse() async throws {
    let requestResponded = expectation(description: "The request was responded to")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)

    let requestCount = Atomic(0)
    server.onPostRequest = { _, data, sendChunk in
      if requestCount.increment() == 1 {
        sendChunk?("""
          {
            "type": "tool_call",
            "toolName": "UnknownTool",
            "input": {},
            "toolUseId": "123",
            "idx": 0
          }
          """.utf8Data)
        return okServerResponse
      } else {
        data.expectToMatch(
          """
          {
            "messages":[
              {"role":"user","content":[{"type":"text","text":"hello"}]},
              {"role":"assistant","content":[
                {"type":"tool_call","toolName":"UnknownTool","toolUseId":"123","input":{"errorDescription":"Missing tool UnknownTool"},"idx" : 0}
              ]},
              {"role":"tool","content":[{"toolUseId":"123","toolName":"UnknownTool","type":"tool_result","result":{"type":"tool_result_failure","failure":"Missing tool UnknownTool"}}]}
            ],
            "model" : "claude-sonnet-4-5-20250929",
            "enableReasoning": false,
            "provider" : {
              "name" : "anthropic",
              "settings" : { "apiKey" : "anthropic-key" }
            },
            "tools":[{"inputSchema":{},"name":"TestTool","description":"tool for testing"}],
            "projectRoot" : "/path/to/root",
            "threadId" : "mock-thread-id"
          }
          """,
          ignoring: "system")
        sendChunk?("""
          {
            "type": "text_delta",
            "text": "Let me fix this",
            "idx": 0
          }
          """.utf8Data)
        requestResponded.fulfill()
        return okServerResponse
      }
    }

    let messages = try await sut.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [TestTool<EmptyObject, String>(output: "test_result")]).lastValue
    #expect(messages.count == 2)

    let firstMessage = try await (#require(messages.first)).lastValue
    let firstMessageContent = firstMessage.content
    #expect(firstMessageContent.count == 1)
    #expect(firstMessageContent.first?.asToolUseRequest != nil)

    let secondMessage = try await (#require(messages.last)).lastValue
    let secondMessageContent = secondMessage.content
    #expect(secondMessageContent.count == 1)
    #expect(secondMessageContent.first?.asText?.content == "Let me fix this")

    try await fulfillment(of: [requestResponded])
  }

  @Test("SendMessage fails with CancellationError when cancelled")
  func test_sendMessage_isCancelled() async throws {
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    let requestStarted = expectation(description: "Request started")
    let requestCancelled = expectation(description: "Request cancelled")
    let updateStreamFinished = expectation(description: "Update stream finished")

    server.onPostRequest = { _, _, _ in
      requestStarted.fulfill()

      try await fulfillment(of: requestCancelled)
      // This will be ignored by the LocalServerMock as we've already returned a cancellation error.
      return okServerResponse
    }

    let task = Task {
      try await sut.sendMessage(
        messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
        tools: [],
        model: .claudeSonnet,
        chatMode: .ask,
        context: TestChatContext(projectRoot: URL(filePath: "/path/to/root")),
        handleUpdateStream: { updateStream in
          Task {
            _ = await updateStream.lastValue
            updateStreamFinished.fulfill()
          }
        })
    }

    // Wait for request to start then cancel
    try await fulfillment(of: requestStarted)
    task.cancel()
    requestCancelled.fulfill()

    try await fulfillment(of: updateStreamFinished)
    do {
      _ = try await task.value
      Issue.record("Expected task to throw cancellation error")
    } catch is CancellationError {
      // Expected cancellation
    }
  }

  @Test("SendMessage stops streaming when cancelled")
  func test_sendMessage_stopsStreamingWhenCancelled() async throws {
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    let requestStarted = expectation(description: "Request started")
    let requestCancelled = expectation(description: "Request cancelled")
    let updateStreamFinished = expectation(description: "Update stream finished")

    server.onPostRequest = { _, _, sendChunk in
      requestStarted.fulfill()

      try await fulfillment(of: requestCancelled)

      // While we expect URLSession to not send any partial response after the request is cancelled,
      // we still validate that our API layer would stop the streaming and not fail if that was to happen.
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "hi",
          "idx": 0
        }
        """.utf8Data)

      // This will be ignored by the LocalServerMock as we've already returned a cancellation error.
      return okServerResponse
    }

    let task = Task {
      try await sut.sendMessage(
        messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
        tools: [],
        model: .claudeSonnet,
        chatMode: .ask,
        context: TestChatContext(projectRoot: URL(filePath: "/path/to/root")),
        handleUpdateStream: { updateStream in
          Task {
            let messages = await updateStream.lastValue
            #expect(messages.count == 1)
            #expect(messages.first?.content.count == 0)
            updateStreamFinished.fulfill()
          }
        })
    }

    // Wait for request to start then cancel
    try await fulfillment(of: [requestStarted])
    task.cancel()
    requestCancelled.fulfill()

    try await fulfillment(of: updateStreamFinished)
    do {
      _ = try await task.value
      Issue.record("Expected task to throw cancellation error")
    } catch is CancellationError {
      // Expected cancellation
    }
  }

  @Test("SendMessage fails if API provider is not configured")
  func test_sendMessage_failsWithNoAPIProvider() async throws {
    let sut = DefaultLLMService(settingsService: MockSettingsService())
    do {
      _ = try await sut.sendMessage(
        messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
        model: .claudeSonnet,
        chatMode: .ask,
        context: TestChatContext(projectRoot: URL(filePath: "/path/to/root")),
        handleUpdateStream: { _ in })
      Issue.record("Expected sendMessage to throw error")
    } catch {
      #expect(error.localizedDescription == "Unsupported model claude-4-sonnet")
    }
  }

  @Test("SendMessage receives reasoning chunks")
  func test_sendMessage_receivesReasoningChunks() async throws {
    let chunksReceived = expectation(description: "All chunk received")
    let messagesUpdatesReceived = expectation(description: "All messages update received")
    let firstMessageUpdatesReceived = expectation(description: "All updates for the first message received")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      sendChunk?("""
        {
          "type": "reasoning_delta",
          "delta": "hi",
          "idx": 0
        }
        """.utf8Data)
      sendChunk?("""
        {
          "type": "reasoning_delta",
          "delta": " what can I do?",
          "idx": 1
        }
        """.utf8Data)
      return okServerResponse
    }
    let updatingMessages = try await sut.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [])

    let messagesUpdateCount = Atomic(0)
    let firstMessageUpdateCount = Atomic(0)
    let contentUpdateCount = Atomic(0)
    Task {
      for await messages in updatingMessages.futureUpdates {
        let count = messagesUpdateCount.increment()
        if count == 1 {
          // First update has one message
          #expect(messages.count == 1)

          let updatingMessage = try #require(messages.first)

          for await message in updatingMessage.futureUpdates {
            let firstCount = firstMessageUpdateCount.increment()
            if firstCount == 1 {
              // First update has one piece of text content
              #expect(message.content.count == 1)
              let updatingTextContent = try #require(message.content.first?.asReasoning)

              for await textContent in updatingTextContent.futureUpdates {
                let contentCount = contentUpdateCount.increment()
                if contentCount == 1 {
                  #expect(textContent.content == "hi what can I do?")
                  #expect(textContent.deltas == ["hi", " what can I do?"])
                }
              }
              chunksReceived.fulfill()
            }
          }
          firstMessageUpdatesReceived.fulfill()
        }
      }
      messagesUpdatesReceived.fulfill()
    }

    try await fulfillment(of: [messagesUpdatesReceived, firstMessageUpdatesReceived, chunksReceived])
    #expect(messagesUpdateCount.value == 1)
    #expect(firstMessageUpdateCount.value == 1)
    #expect(contentUpdateCount.value == 1)
  }

  @Test("SendMessage with message history containing reasoning")
  func test_sendMessage_withReasoningInHistory() async throws {
    let requestResponded = expectation(description: "The request was responded to")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, data, sendChunk in
      data.expectToMatch(
        """
        {
          "messages":[
            {"role":"user","content":[{"type":"text","text":"hello"}]},
            {"role":"assistant","content":[
              {"type":"reasoning","text":"Let me think about this...","signature":"test-sig"},
              {"type":"text","text":"Hi there!"}
            ]},
            {"role":"user","content":[{"type":"text","text":"follow up"}]}
          ],
          "model" : "claude-sonnet-4-5-20250929",
          "enableReasoning": false,
          "provider" : {
            "name" : "anthropic",
            "settings" : { "apiKey" : "anthropic-key" }
          },
          "tools":[],
          "projectRoot" : "/path/to/root",
          "threadId" : "mock-thread-id"
        }
        """,
        ignoring: "system")
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "Got it!",
          "idx": 0
        }
        """.utf8Data)
      requestResponded.fulfill()
      return okServerResponse
    }

    let messages = try await sut.sendMessage(
      messageHistory: [
        .init(role: .user, content: [.textMessage(.init(text: "hello"))]),
        .init(role: .assistant, content: [
          .reasoningMessage(.init(text: "Let me think about this...", signature: "test-sig")),
          .textMessage(.init(text: "Hi there!")),
        ]),
        .init(role: .user, content: [.textMessage(.init(text: "follow up"))]),
      ],
      tools: []).lastValue

    #expect(messages.count == 1)
    try await fulfillment(of: [requestResponded])
  }

  @Test("SendMessage receives text and reasoning chunks")
  func test_sendMessage_receivesTextAndReasoningChunks() async throws {
    let messagesUpdatesReceived = expectation(description: "All messages update received")
    let firstMessageUpdatesReceived = expectation(description: "All updates for the first message received")
    let firstContentChunksReceived = expectation(description: "All chunk received")
    let secondContentChunksReceived = expectation(description: "All chunk received")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      sendChunk?("""
        {
          "type": "reasoning_delta",
          "delta": "let's",
          "idx": 0
        }
        """.utf8Data)
      sendChunk?("""
        {
          "type": "reasoning_delta",
          "delta": " ultrathink",
          "idx": 1
        }
        """.utf8Data)
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "the solution",
          "idx": 2
        }
        """.utf8Data)
      sendChunk?("""
        {
          "type": "text_delta",
          "text": " is obvious",
          "idx": 3
        }
        """.utf8Data)
      return okServerResponse
    }
    let updatingMessages = try await sut.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [])

    let messagesUpdateCount = Atomic(0)
    let firstMessageUpdateCount = Atomic(0)
    Task {
      for await messages in updatingMessages.futureUpdates {
        let count = messagesUpdateCount.increment()
        if count == 1 {
          // First update has one message
          #expect(messages.count == 1)

          let updatingMessage = try #require(messages.first)

          for await message in updatingMessage.futureUpdates {
            let firstCount = firstMessageUpdateCount.increment()
            if firstCount == 1 {
              var contentUpdateCount = 0
              // First update has one piece of text content
              #expect(message.content.count == 1)
              let updatingTextContent = try #require(message.content.first?.asReasoning)

              for await textContent in updatingTextContent.futureUpdates {
                contentUpdateCount += 1
                if contentUpdateCount == 1 {
                  #expect(textContent.content == "let's ultrathink")
                  #expect(textContent.deltas == ["let's", " ultrathink"])
                }
              }
              firstContentChunksReceived.fulfill()
            } else {
              var contentUpdateCount = 0
              // First update has one piece of text content
              #expect(message.content.count == 2)
              let updatingTextContent = try #require(message.content.last?.asText)

              for await textContent in updatingTextContent.futureUpdates {
                contentUpdateCount += 1
                if contentUpdateCount == 1 {
                  #expect(textContent.content == "the solution is obvious")
                  #expect(textContent.deltas == ["the solution", " is obvious"])
                }
              }
              secondContentChunksReceived.fulfill()
            }
          }
          firstMessageUpdatesReceived.fulfill()
        }
      }
      messagesUpdatesReceived.fulfill()
    }

    try await fulfillment(of: [
      messagesUpdatesReceived,
      firstMessageUpdatesReceived,
      firstContentChunksReceived,
      secondContentChunksReceived,
    ])
    #expect(messagesUpdateCount.value == 1)
    #expect(firstMessageUpdateCount.value == 2)
  }

  @Test("SendMessage with tool use that has bad input sends detailed error message")
  func test_sendMessage_withBadToolInput() async throws {
    let requestResponded = expectation(description: "The request was responded to")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)

    let requestCount = Atomic(0)
    server.onPostRequest = { _, data, sendChunk in
      if requestCount.increment() == 1 {
        // First request: LLM sends a tool use with bad input (wrong type for 'file' field)
        sendChunk?("""
          {
            "type": "tool_call",
            "toolName": "TestTool",
            "input": {"file": 123, "keywords": "should be array"},
            "toolUseId": "bad-input-tool-123",
            "idx": 0
          }
          """.utf8Data)
        return okServerResponse
      } else {
        // Second request: Verify that the error message about bad tool input is included
        let requestData = String(data: data, encoding: .utf8) ?? ""
        #expect(requestData.contains("tool_result_failure"))
        #expect(requestData
          .contains(
            "Could not parse the input for tool TestTool: Error at coding path: '.file': Expected to decode String but found number instead."))

        sendChunk?("""
          {
            "type": "text_delta",
            "text": "I'll fix that input format",
            "idx": 0
          }
          """.utf8Data)
        requestResponded.fulfill()
        return okServerResponse
      }
    }

    let messages = try await sut.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [TestTool<TestToolInput, String>(output: "test_result")]).lastValue
    #expect(messages.count == 2)

    let firstMessage = try await (#require(messages.first)).lastValue
    let firstMessageContent = firstMessage.content
    #expect(firstMessageContent.count == 1)

    // Verify the FailedToolUse is created with detailed error description
    if let toolUseMessage = firstMessageContent.first?.asToolUseRequest {
      if let failedToolUse = toolUseMessage.toolUse as? FailedToolUse {
        #expect(failedToolUse.toolUseId == "bad-input-tool-123")
        #expect(failedToolUse.toolName == "TestTool")
        // Validate core properties - the exact message format may have smart quotes
        #expect(failedToolUse
          .errorDescription ==
          "Could not parse the input for tool TestTool: Error at coding path: '.file': Expected to decode String but found number instead.")
      } else {
        Issue.record("Expected FailedToolUse for bad input, got \(type(of: toolUseMessage.toolUse))")
      }
    } else {
      Issue.record("Expected tool use request in first message")
    }

    let secondMessage = try await (#require(messages.last)).lastValue
    let secondMessageContent = secondMessage.content
    #expect(secondMessageContent.count == 1)
    #expect(secondMessageContent.first?.asText?.content == "I'll fix that input format")

    try await fulfillment(of: [requestResponded])
  }
}
