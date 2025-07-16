// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import LLMFoundation
import LLMServiceInterface
import ServerServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
import ToolFoundation

@testable import LLMService

// MARK: - SummarizeConversationTests

final class SummarizeConversationTests {

  // MARK: - Test summarizeConversation with successful response

  @Test
  func test_summarizeConversation_withSuccessfulResponse() async throws {
    // Given
    let mockServer = MockServer()
    let service = DefaultLLMService(server: mockServer)

    let messageHistory: [Schema.Message] = [
      .init(
        role: .user,
        content: [.textMessage(.init(text: "Can you help me fix a bug in my login function?"))]),
      .init(
        role: .assistant,
        content: [.textMessage(.init(text: "Sure! What's the issue you're experiencing?"))]),
      .init(
        role: .user,
        content: [.textMessage(.init(text: "Users can't log in with their email addresses."))]),
    ]

    let expectedSummary =
      "The conversation focused on fixing a login bug where users couldn't log in with email addresses. The assistant offered to help diagnose and resolve the authentication issue."

    // Configure mock server to return expected response
    mockServer.onPostRequest = { _, _, sendChunk in
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "\(expectedSummary)",
          "idx": 0
        }
        """.utf8Data)
      return Data()
    }

    // When
    let summary = try await service.summarizeConversation(
      messageHistory: messageHistory,
      model: .claudeSonnet_4_0)

    // Then
    #expect(summary == expectedSummary)
  }

  // MARK: - Test summarizeConversation with empty response

  @Test
  func test_summarizeConversation_withEmptyResponse() async throws {
    // Given
    let mockServer = MockServer()
    let service = DefaultLLMService(server: mockServer)

    let messageHistory: [Schema.Message] = [
      .init(
        role: .user,
        content: [.textMessage(.init(text: "Test message"))]),
    ]

    // Configure mock server to return empty response
    mockServer.onPostRequest = { _, _, _ in
      Data()
    }

    // When
    let summary = try await service.summarizeConversation(
      messageHistory: messageHistory,
      model: .claudeSonnet_4_0)

    // Then
    #expect(summary == "")
  }

  // MARK: - Test summarizeConversation with server error

  @Test
  func test_summarizeConversation_withServerError() async throws {
    // Given
    let mockServer = MockServer()
    let service = DefaultLLMService(server: mockServer)

    let messageHistory: [Schema.Message] = [
      .init(
        role: .user,
        content: [.textMessage(.init(text: "Test message"))]),
    ]

    // Configure mock server to return error
    mockServer.onPostRequest = { _, _, _ in
      throw AppError(message: "Server error")
    }

    // When/Then
    await #expect(throws: AppError.self) {
      _ = try await service.summarizeConversation(
        messageHistory: messageHistory,
        model: .claudeSonnet_4_0)
    }
  }

  // MARK: - Test summarizeConversation with empty message history

  @Test
  func test_summarizeConversation_withEmptyMessageHistory() async throws {
    // Given
    let mockServer = MockServer()
    let service = DefaultLLMService(server: mockServer)

    let messageHistory: [Schema.Message] = []

    let expectedSummary = "This conversation appears to be empty with no messages to summarize."

    // Configure mock server to return expected response
    mockServer.onPostRequest = { _, _, sendChunk in
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "\(expectedSummary)",
          "idx": 0
        }
        """.utf8Data)
      return Data()
    }

    // When
    let summary = try await service.summarizeConversation(
      messageHistory: messageHistory,
      model: .claudeSonnet_4_0)

    // Then
    #expect(summary == expectedSummary)
  }

  // MARK: - Test summarizeConversation with long conversation

  @Test
  func test_summarizeConversation_withLongConversation() async throws {
    // Given
    let mockServer = MockServer()
    let service = DefaultLLMService(server: mockServer)

    // Create a longer conversation history
    let messageHistory: [Schema.Message] = [
      .init(role: .user, content: [.textMessage(.init(text: "I need to implement a user authentication system"))]),
      .init(
        role: .assistant,
        content: [.textMessage(.init(text: "I'll help you implement authentication. What technology stack are you using?"))]),
      .init(role: .user, content: [.textMessage(.init(text: "I'm using Swift and want to implement OAuth2"))]),
      .init(role: .assistant, content: [.textMessage(.init(text: "Great! Let's start by setting up the OAuth2 flow..."))]),
      .init(role: .user, content: [.textMessage(.init(text: "How do I handle token refresh?"))]),
      .init(role: .assistant, content: [.textMessage(.init(text: "Token refresh should be handled automatically..."))]),
      .init(role: .user, content: [.textMessage(.init(text: "What about storing tokens securely?"))]),
      .init(role: .assistant, content: [.textMessage(.init(text: "Use the Keychain for secure token storage..."))]),
    ]

    let expectedSummary =
      "The conversation covered implementing a user authentication system in Swift using OAuth2. Key topics included setting up the OAuth2 flow, handling token refresh automatically, and securely storing tokens in the Keychain. The assistant provided guidance on best practices for authentication implementation."

    // Configure mock server to return expected response
    mockServer.onPostRequest = { _, _, sendChunk in
      sendChunk?("""
        {
          "type": "text_delta",
          "text": "\(expectedSummary)",
          "idx": 0
        }
        """.utf8Data)
      return Data()
    }

    // When
    let summary = try await service.summarizeConversation(
      messageHistory: messageHistory,
      model: .claudeSonnet_4_0)

    // Then
    #expect(summary == expectedSummary)
  }
}
