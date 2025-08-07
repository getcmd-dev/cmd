// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LLMFoundation
import ServerServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
@testable import LLMService

struct APIParamsEncodingTests {
  @Test("Message.text encoding")
  func testMessageTextEncoding() throws {
    let message = Schema.Message(role: .user, content: [.textMessage(.init(text: "Hello"))])
    try testEncoding(message, """
      {
        "role" : "user",
        "content" : [
          {
            "text" : "Hello",
            "type" : "text"
          }
        ]
      }
      """)
  }

  @Test("Message.toolResult success encoding")
  func testToolResultSuccessEncoding() throws {
    let toolResult = Schema.ToolResultMessage(
      toolUseId: "123",
      toolName: "someTool",
      result: .success([
        "result": .string("Result"),
      ]))
    let message = Schema.Message(role: .tool, content: [.toolResultMessage(toolResult)])

    try testEncoding(message, """
      {        
        "role" : "tool",
        "content" : [
          {
            "type" : "tool_result",
            "result" : {
              "type" : "tool_result_success",
              "success" : {
                "result" : "Result"
              }
            },
            "toolName" : "someTool",
            "toolUseId" : "123"
          }
        ]
      }
      """)
  }

  @Test("Message.toolResult error encoding")
  func testToolResultErrorEncoding() throws {
    let toolResult = Schema.ToolResultMessage(
      toolUseId: "123",
      toolName: "someTool",
      result: .failure("Error occurred"))
    let message = Schema.Message(role: .tool, content: [.toolResultMessage(toolResult)])

    try testEncoding(message, """
      {        
        "role" : "tool",
        "content" : [
          {
            "type" : "tool_result",
            "result" : {
              "type" : "tool_result_failure",
              "failure" : {
                "error" : "Error occurred"
              }
            },
            "toolName" : "someTool",
            "toolUseId" : "123"
          }
        ]
      }
      """)
  }

  @Test("SendMessagesParams encoding")
  func testSendMessagesParamsEncoding() throws {
    let messages: [Schema.Message] = [
      Schema.Message(role: .user, content: [.textMessage(Schema.TextMessage(text: "Hello"))]),
      Schema.Message(role: .assistant, content: [.textMessage(Schema.TextMessage(text: "Hi"))]),
    ]

    let params = Schema.SendMessageRequestParams(
      messages: messages,
      system: "Be helpful",
      projectRoot: "/path/to/workspace",
      tools: [],
      model: "claude-3.5-sonnet",
      enableReasoning: false,
      provider: .init(name: .anthropic, settings: .init()))

    try testEncoding(params, """
      {
        "system" : "Be helpful",
        "tools" : [],
        "model" : "claude-3.5-sonnet",
        "enableReasoning": false,
        "provider" : {
          "name" : "anthropic",
          "settings" : {}
        },
        "projectRoot": "/path/to/workspace",
        "messages" : [
          {
            "role" : "user",
            "content" : [
              {
                "text" : "Hello",
                "type" : "text"
              }
            ]
          },
          {
            "role" : "assistant", 
            "content" : [
              {
                "text" : "Hi",
                "type" : "text"
              }
            ]
          }
        ]
      }
      """)
  }

  @Test("ToolResultParam encoding")
  func testToolResultParamEncoding() throws {
    try testEncoding(Schema.ToolResultMessage(
      toolUseId: "123",
      toolName: "someTool",
      result: .success([:])), """
        {
          "result" : {
            "success" : {

            },
            "type" : "tool_result_success"
          },
          "toolName" : "someTool",
          "toolUseId" : "123",
          "type" : "tool_result"
        }
        """)

    try testEncoding(Schema.ToolResultMessage(
      toolUseId: "123",
      toolName: "someTool",
      result: .success(["it": .string("worked!")])), """
        {
          "result" : {
            "success" : {
              "it" : "worked!"
            },
            "type" : "tool_result_success"
          },
          "toolUseId" : "123",
          "toolName" : "someTool",
          "type" : "tool_result"
        }
        """)
  }

  @Test("EnableReasoning parameter set to true for enabled reasoning-capable models")
  func testEnableReasoningTrueForEnableReasoningModels() async throws {
    let requestCompleted = expectation(description: "Request completed")
    let mockServer = MockServer()
    let settingsService = MockSettingsService(.init(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: LLMProviderSettings(
          apiKey: "anthropic-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ],
      reasoningModels: [.claudeSonnet: .init(isEnabled: true)]))
    let service = DefaultLLMService(server: mockServer, settingsService: settingsService)

    mockServer.onPostRequest = { path, data, _ in
      #expect(path == "sendMessage")
      data.expectToMatch("""
        {
          "messages" : [
            {
              "content" : [
                {
                  "text" : "Hello",
                  "type" : "text"
                }
              ],
              "role" : "user"
            }
          ],
          "model" : "claude-sonnet-4-20250514",
          "enableReasoning": true,
          "provider" : {
            "name" : "anthropic",
            "settings" : { "apiKey" : "anthropic-key" }
          },
          "tools" : [],
          "projectRoot" : "/test",
          "threadId" : "mock-thread-id"
        }
        """, ignoring: "system")
      requestCompleted.fulfill()
      return okServerResponse
    }

    // Use a model that supports reasoning
    let reasoningModel = LLMModel.claudeSonnet
    #expect(reasoningModel.canReason == true)

    _ = try await service.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "Hello"))])],
      tools: [],
      model: reasoningModel,
      chatMode: .ask,
      context: TestChatContext(projectRoot: URL(filePath: "/test")),
      handleUpdateStream: { _ in })

    try await fulfillment(of: [requestCompleted])
  }

  @Test("EnableReasoning parameter set to true for non-enabled reasoning-capable models")
  func testEnableReasoningTrueForNonEnableReasoningModels() async throws {
    let requestCompleted = expectation(description: "Request completed")
    let mockServer = MockServer()
    let service = DefaultLLMService(server: mockServer)

    mockServer.onPostRequest = { path, data, _ in
      #expect(path == "sendMessage")
      data.expectToMatch("""
        {
          "messages" : [
            {
              "content" : [
                {
                  "text" : "Hello",
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
          "projectRoot" : "/test",
          "threadId" : "mock-thread-id"
        }
        """, ignoring: "system")
      requestCompleted.fulfill()
      return okServerResponse
    }

    // Use a model that supports reasoning
    let reasoningModel = LLMModel.claudeSonnet
    #expect(reasoningModel.canReason == true)

    _ = try await service.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "Hello"))])],
      tools: [],
      model: reasoningModel,
      chatMode: .ask,
      context: TestChatContext(projectRoot: URL(filePath: "/test")),
      handleUpdateStream: { _ in })

    try await fulfillment(of: [requestCompleted])
  }

  @Test("EnableReasoning parameter set to false for non-reasoning models")
  func testEnableReasoningFalseForNonReasoningModels() async throws {
    let requestCompleted = expectation(description: "Request completed")
    let mockServer = MockServer()
    let service = DefaultLLMService(server: mockServer)

    mockServer.onPostRequest = { path, data, _ in
      #expect(path == "sendMessage")
      data.expectToMatch("""
        {
          "messages" : [
            {
              "content" : [
                {
                  "text" : "Hello",
                  "type" : "text"
                }
              ],
              "role" : "user"
            }
          ],
          "model" : "claude-3-5-haiku-latest",
          "enableReasoning": false,
          "provider" : {
            "name" : "anthropic",
            "settings" : { "apiKey" : "anthropic-key" }
          },
          "tools" : [],
          "projectRoot" : "/test",
          "threadId" : "mock-thread-id"
        }
        """, ignoring: "system")
      requestCompleted.fulfill()
      return okServerResponse
    }

    // Use a model that doesn't support reasoning
    let nonReasoningModel = LLMModel.claudeHaiku_3_5
    #expect(nonReasoningModel.canReason == false)

    _ = try await service.sendMessage(
      messageHistory: [.init(role: .user, content: [.textMessage(.init(text: "Hello"))])],
      tools: [],
      model: nonReasoningModel,
      chatMode: .ask,
      context: TestChatContext(projectRoot: URL(filePath: "/test")),
      handleUpdateStream: { _ in })

    try await fulfillment(of: [requestCompleted])
  }
}
