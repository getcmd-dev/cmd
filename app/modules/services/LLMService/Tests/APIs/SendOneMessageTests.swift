// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation
import LLMServiceInterface
import LocalServerServiceInterface
import SnapshotTesting
import SwiftTesting
import Testing

@testable import LLMService

final class SendOneMessageTests {

  @Test("SendOneMessage sends correct payload")
  func test_sendOneMessage_sendsCorrectPayload() async throws {
    let requestCompleted = expectation(description: "The request completed")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { path, data, _ in
      #expect(path == "sendMessage")
      data.expectToMatch("""
        {
          "messages" : [
            {
              "content" : [
                {
                  "text" : "hello",
                  "type" : "text"
                }
              ],
              "role" : "user"
            }
          ],
          "model" : "claude-sonnet-4-20250514",
          "enableReasoning": false,
          "provider" : {
            "name" : "anthropic",
            "settings" : { "apiKey" : "anthropic-key" }
          },
          "tools" : [],
          "projectRoot" : "/path/to/root",
          "threadId" : "mock-thread-id"
        }
        """, ignoring: "system")
      requestCompleted.fulfill()
      return okServerResponse
    }
    _ = try await sut.sendOneMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [])

    try await fulfillment(of: [requestCompleted])
  }

  @Test("SendOneMessage sends payload with correct fields ordering")
  func test_sendOneMessage_sendsPayloadWithCorrectFieldsOrdering() async throws {
    let requestCompleted = expectation(description: "The request completed")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { path, data, _ in
      #expect(path == "sendMessage")
      assertSnapshot(of: String(data: data, encoding: .utf8), as: .dump)
      requestCompleted.fulfill()
      return okServerResponse
    }
    _ = try await sut.sendOneMessage(
      messageHistory: [
        .init(role: .user, content: [.textMessage(.init(text: "hello"))]),
        .init(role: .tool, content: [.toolUseRequest(.init(toolName: "someTool", input: .object([
          "z": "Z",
          "a": "A",
          "e": .array([
            .object([
              "x": "X",
              "b": "B",
            ]),
            .object([
              "a": "a",
              "b": "B",
            ]),
          ]),
        ]), toolUseId: "23123", idx: 0))]),
      ],
      tools: [])

    try await fulfillment(of: [requestCompleted])
  }

  @Test("SendOneMessage receives text chunks")
  func test_sendOneMessage() async throws {
    let initialStreamExpectationValidated = expectation(description: "initial stream expectation validated")
    let chunksReceived = expectation(description: "All chunk received")
    let messageUpdatesReceived = expectation(description: "All message update received")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      // Wait here to avoid concurrency issues that would make the test flaky.
      try await fulfillment(of: initialStreamExpectationValidated)
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
    let updatingMessage = try await sut.sendOneMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [])
    #expect(updatingMessage.content.count == 0)
    initialStreamExpectationValidated.fulfill()

    let messageUpdateCount = Atomic(0)
    let contentUpdateCount = Atomic(0)
    Task {
      for await message in updatingMessage.futureUpdates {
        let count = messageUpdateCount.increment()
        if count == 1 {
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
      messageUpdatesReceived.fulfill()
    }

    try await fulfillment(of: [messageUpdatesReceived, chunksReceived])
    #expect(messageUpdateCount.value == 1)
    #expect(contentUpdateCount.value == 1)
  }

  @Test("SendOneMessage with bad data receives valid text chunks and completes")
  func test_sendOneMessage_withBadData() async throws {
    let initialStreamExpectationValidated = expectation(description: "initial stream expectation validated")
    let chunksReceived = expectation(description: "All chunk received")
    let messageUpdatesReceived = expectation(description: "All message update received")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      // Wait here to avoid concurrency issues that would make the test flaky.
      try await fulfillment(of: initialStreamExpectationValidated)
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
          "texxxxxt": " what can I do?"
        }
        """.utf8Data)
      return okServerResponse
    }
    let updatingMessage = try await sut.sendOneMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [])
    #expect(updatingMessage.content.count == 0)
    initialStreamExpectationValidated.fulfill()

    let messageUpdateCount = Atomic(0)
    let contentUpdateCount = Atomic(0)
    Task {
      for await message in updatingMessage.futureUpdates {
        let count = messageUpdateCount.increment()
        if count == 1 {
          // First update has one piece of text content
          #expect(message.content.count == 1)
          let updatingTextContent = try #require(message.content.first?.asText)

          for await textContent in updatingTextContent.futureUpdates {
            let contentCount = contentUpdateCount.increment()
            if contentCount == 1 {
              #expect(textContent.content == "hi")
              #expect(textContent.deltas == ["hi"])
            }
          }
          chunksReceived.fulfill()
        }
      }
      messageUpdatesReceived.fulfill()
    }

    try await fulfillment(of: [messageUpdatesReceived, chunksReceived])
    #expect(messageUpdateCount.value == 1)
    #expect(contentUpdateCount.value == 0)
  }

  @Test("SendOneMessage with text chunks tool use")
  func test_sendOneMessage_withToolCall() async throws {
    let toolCallReceived = expectation(description: "tool Call received")
    let messagesReceived = expectation(description: "All message update received")
    let initialStreamExpectationValidated = expectation(description: "initial stream expectation validated")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      // Wait here to avoid concurrency issues that would make the test flaky.
      try await fulfillment(of: initialStreamExpectationValidated)
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
      sendChunk?("""
        {
          "type": "tool_call",
          "toolName": "read_file",
          "toolUseId": "123",
          "input": {
            "file": "file.txt"
          },
          "idx": 2
        }
        """.utf8Data)
      return okServerResponse
    }
    let updatingMessage = try await sut.sendOneMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [TestTool<TestToolInput, EmptyObject>(name: "read_file", output: EmptyObject())])
    #expect(updatingMessage.content.count == 0)
    initialStreamExpectationValidated.fulfill()

    let messageUpdateCount = Atomic(0)
    Task {
      for await message in updatingMessage.futureUpdates {
        let count = messageUpdateCount.increment()
        if count == 1 {
          // First update has one piece of text content
          #expect(message.content.count == 1)
          #expect(message.content.first?.asText != nil)
        } else if count == 2 {
          // Second update has a tool call
          #expect(message.content.count == 2)
          let toolCall = try #require(message.content.last?.asToolUseRequest)
          #expect(toolCall.toolName == "read_file")
          #expect(toolCall.toolUse.toolUseId == "123")
          #expect((toolCall.toolUse.input as? TestToolInput)?.file == "file.txt")
          toolCallReceived.fulfill()
        }
      }
      messagesReceived.fulfill()
    }

    try await fulfillment(of: [toolCallReceived, messagesReceived])
    #expect(messageUpdateCount.value == 2)
  }

  @Test("SendOneMessage with failed tool use")
  func test_sendOneMessage_withFailedToolCall() async throws {
    let toolCallReceived = expectation(description: "tool Call received")
    let messagesReceived = expectation(description: "All message update received")
    let initialStreamExpectationValidated = expectation(description: "initial stream expectation validated")
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      // Wait here to avoid concurrency issues that would make the test flaky.
      try await fulfillment(of: initialStreamExpectationValidated)
      sendChunk?("""
        {
          "type": "tool_call",
          "toolName": "read_file",
          "toolUseId": "123",
          "input": {
            "badInput": "file.txt"
          },
          "idx": 0
        }
        """.utf8Data)
      return okServerResponse
    }
    let updatingMessage = try await sut.sendOneMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [TestTool<TestToolInput, EmptyObject>(name: "read_file", output: EmptyObject())])
    #expect(updatingMessage.content.count == 0)
    initialStreamExpectationValidated.fulfill()

    Task {
      for await message in updatingMessage.futureUpdates {
        // Second update has a tool call
        #expect(message.content.count == 1)
        let toolCall = try #require(message.content.last?.asToolUseRequest)
        #expect(toolCall.toolName == "read_file")
        #expect(toolCall.toolUse.toolUseId == "123")
        #expect(
          (toolCall.toolUse as? FailedToolUse)?.errorDescription ==
            "Could not parse the input for tool read_file: Error at coding path: \'\': No value associated with key CodingKeys(stringValue: \"file\", intValue: nil) (\"file\").")
        toolCallReceived.fulfill()
      }
      messagesReceived.fulfill()
    }

    try await fulfillment(of: [toolCallReceived, messagesReceived])
  }

  @Test("SendOneMessage fails with CancellationError when cancelled")
  func test_sendOneMessage_isCancelled() async throws {
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
      try await sut.sendOneMessage(
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
        },
        handleUsageInfo: { _ in })
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

  @Test("SendOneMessage stops streaming when cancelled")
  func test_sendOneMessage_stopsStreamingWhenCancelled() async throws {
    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    let requestStarted = expectation(description: "Request started")
    let requestCancelled = expectation(description: "Request cancelled")
    let updateStreamFinished = expectation(description: "Update stream finished")

    server.onPostRequest = { _, _, sendChunk in
      requestStarted.fulfill()

      try await fulfillment(of: requestCancelled)

      // While we expect URLSession to not send and partial response after the request is cancelled,
      // we still validate that our API layer would stop the streaming and not fail if that was to happen.
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "hi"
        }
        """.utf8Data)

      // This will be ignored by the LocalServerMock as we've already returned a cancellation error.
      return okServerResponse
    }

    let task = Task {
      try await sut.sendOneMessage(
        messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
        tools: [],
        model: .claudeSonnet,
        chatMode: .ask,
        context: TestChatContext(projectRoot: URL(filePath: "/path/to/root")),
        handleUpdateStream: { updateStream in
          Task {
            for await _ in updateStream.futureUpdates {
              Issue.record("Expected no updates")
            }
            updateStreamFinished.fulfill()
          }
        },
        handleUsageInfo: { _ in })
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

  @Test("SendOneMessage with streamed tool call receives all input updates")
  func test_sendOneMessage_withStreamedToolCall() async throws {
    let initialStreamExpectationValidated = expectation(description: "initial stream expectation validated")
    let toolCallReceived = expectation(description: "tool Call received")
    let messagesReceived = expectation(description: "All message update received")

    let chunk1Validated = expectation(description: "First chunk validated")
    let chunk2Validated = expectation(description: "Second chunk validated")
    let chunk3Validated = expectation(description: "Third chunk validated")
    let chunk4Validated = expectation(description: "Fourth chunk validated")
    let toolCallValidated = expectation(description: "Tool call validated")

    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      // Wait here to avoid concurrency issues that would make the test flaky.
      try await fulfillment(of: initialStreamExpectationValidated)
      sendChunk?("""
        {
          "type": "tool_call_delta",
          "toolName": "TestStreamingTool",
          "toolUseId": "123",
          "inputDelta": "{\\"file\\": \\"file.t",
          "idx": 0
        }
        """.utf8Data)

      try await fulfillment(of: chunk1Validated)
      sendChunk?("""
        {
          "type": "tool_call_delta",
          "toolName": "TestStreamingTool",
          "toolUseId": "123",
          "inputDelta": "xt\\"",
          "idx": 1
        }
        """.utf8Data)

      try await fulfillment(of: chunk2Validated)
      sendChunk?("""
        {
          "type": "tool_call_delta",
          "toolName": "TestStreamingTool",
          "toolUseId": "123",
          "inputDelta": ", \\"keywords\\":[\\"foo\\", \\"ba",
          "idx": 2
        }
        """.utf8Data)

      try await fulfillment(of: chunk3Validated)
      sendChunk?("""
        {
          "type": "tool_call_delta",
          "toolName": "TestStreamingTool",
          "toolUseId": "123",
          "inputDelta": "r\\"]}",
          "idx": 3
        }
        """.utf8Data)

      try await fulfillment(of: chunk4Validated)
      sendChunk?("""
        {
          "type": "tool_call",
          "toolName": "TestStreamingTool",
          "toolUseId": "123",
          "input": {
            "file": "file.txt",
            "keywords": ["foo", "bar"]
          },
          "idx": 4
        }
        """.utf8Data)
      return okServerResponse
    }
    let updatingMessage = try await sut.sendOneMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [TestStreamingTool<TestToolInput, EmptyObject>(name: "TestStreamingTool")])
    #expect(updatingMessage.content.count == 0)
    initialStreamExpectationValidated.fulfill()

    let _toolUse = Atomic<TestStreamingTool<TestToolInput, EmptyObject>.Use?>(nil)
    Task {
      for await message in updatingMessage.futureUpdates {
        // Second update has a tool call
        #expect(message.content.count == 1)
        let toolUse = try #require(message.content.last?.asToolUseRequest?.toolUse as? TestStreamingTool<
          TestToolInput,
          EmptyObject,
        >.Use)
        #expect(toolUse.callingTool.name == "TestStreamingTool")
        #expect(toolUse.toolUseId == "123")
        _toolUse.set(to: toolUse)
        toolCallReceived.fulfill()
      }
      messagesReceived.fulfill()
    }

    try await fulfillment(of: [toolCallReceived])
    let toolUse = try #require(_toolUse.value)

    #expect(toolUse.receivedInputs.count == 1)
    #expect(toolUse.receivedInputs.last?.file == "file.t")
    #expect(toolUse.receivedInputs.last?.keywords == nil)
    chunk1Validated.fulfill()

    let counter = Atomic<Int>(1)
    toolUse.onReceiveInput = {
      let i = counter.increment()
      switch i {
      case 2:
        #expect(toolUse.receivedInputs.count == 2)
        #expect(toolUse.receivedInputs.last?.file == "file.txt")
        #expect(toolUse.receivedInputs.last?.keywords == nil)
        chunk2Validated.fulfill()

      case 3:
        #expect(toolUse.receivedInputs.count == 3)
        #expect(toolUse.receivedInputs.last?.file == "file.txt")
        #expect(toolUse.receivedInputs.last?.keywords == ["foo", "ba"])
        chunk3Validated.fulfill()

      case 4:
        #expect(toolUse.receivedInputs.count == 4)
        #expect(toolUse.receivedInputs.last?.file == "file.txt")
        #expect(toolUse.receivedInputs.last?.keywords == ["foo", "bar"])
        #expect(toolUse.isInputComplete == false)
        chunk4Validated.fulfill()

      case 5:
        #expect(toolUse.receivedInputs.count == 5)
        #expect(toolUse.receivedInputs.last?.file == "file.txt")
        #expect(toolUse.receivedInputs.last?.keywords == ["foo", "bar"])
        #expect(toolUse.isInputComplete == true)
        toolCallValidated.fulfill()

      default:
        Issue.record("Received unexpected input update #\(i)")
      }
    }

    try await fulfillment(of: [messagesReceived, toolCallValidated])
  }

  @Test("SendOneMessage with streamed tool call works if some updates can't be parsed")
  func test_sendOneMessage_withStreamedToolCall_worksIfSomeUpdateCantBeParsed() async throws {
    let initialStreamExpectationValidated = expectation(description: "initial stream expectation validated")
    let messagesReceived = expectation(description: "All message update received")

    let server = MockLocalServer()
    let sut = DefaultLLMService(server: server)
    server.onPostRequest = { _, _, sendChunk in
      // Wait here to avoid concurrency issues that would make the test flaky.
      try await fulfillment(of: initialStreamExpectationValidated)
      sendChunk?("""
        {
          "type": "tool_call_delta",
          "toolName": "TestStreamingTool",
          "toolUseId": "123",
          "inputDelta": "{\\"fil",
          "idx": 0
        }
        """.utf8Data)

      sendChunk?("""
        {
          "type": "tool_call_delta",
          "toolName": "TestStreamingTool",
          "toolUseId": "123",
          "inputDelta": "e\\": \\"file.txt\\"}",
          "idx": 1
        }
        """.utf8Data)

      sendChunk?("""
        {
          "type": "tool_call",
          "toolName": "TestStreamingTool",
          "toolUseId": "123",
          "input": {
            "file": "file.txt"
          },
          "idx": 2
        }
        """.utf8Data)
      return okServerResponse
    }
    let updatingMessage = try await sut.sendOneMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "hello"))])],
      tools: [TestStreamingTool<TestToolInput, EmptyObject>(name: "TestStreamingTool")])
    #expect(updatingMessage.content.count == 0)
    initialStreamExpectationValidated.fulfill()

    let _toolUse = Atomic<TestStreamingTool<TestToolInput, EmptyObject>.Use?>(nil)
    Task {
      for await message in updatingMessage.futureUpdates {
        // Second update has a tool call
        #expect(message.content.count == 1)
        let toolUse = try #require(message.content.last?.asToolUseRequest?.toolUse as? TestStreamingTool<
          TestToolInput,
          EmptyObject,
        >.Use)
        #expect(toolUse.callingTool.name == "TestStreamingTool")
        #expect(toolUse.toolUseId == "123")
        _toolUse.set(to: toolUse)
      }
      messagesReceived.fulfill()
    }

    try await fulfillment(of: [messagesReceived])
    let toolUse = try #require(_toolUse.value)

    #expect(toolUse.receivedInputs.count == 2)
    #expect(toolUse.receivedInputs.last?.file == "file.txt")
    #expect(toolUse.isInputComplete == true)
  }
}
