// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppEventServiceInterface
import ChatFeatureInterface
import Combine
import ConcurrencyFoundation
import Dependencies
import DependenciesTestSupport
import ExtensionEventsInterface
import Foundation
import JSONFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import SharedValuesFoundation
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

// MARK: - ChatMessageViewModelTests

@MainActor
struct ChatMessageViewModelTests {

  @Suite("API Format Tests")
  struct APIFormatTests {

    @MainActor
    @Test("Text content creates single message with user role")
    func test_apiFormat_createsUserMessage() async throws {
      // given
      let sut = ChatMessageViewModel(
        content: [
          .text(ChatMessageTextContent(projectRoot: nil, text: "Hello world", attachments: [])),
          .text(ChatMessageTextContent(projectRoot: nil, text: "Second message", attachments: [])),
        ],
        role: .user)

      // when
      let messages = sut.apiFormat

      // then
      #expect(messages.count == 1)
      #expect(messages[0].role == Schema.Message.Role.user)
      #expect(messages[0].content.count == 2)
      #expect(messages[0].content[0].text == "Hello world")
      #expect(messages[0].content[1].text == "Second message")
    }

    @MainActor
    @Test("Assistant role creates assistant message")
    func test_apiFormat_createsAssistantMessage() async throws {
      // given
      let sut = ChatMessageViewModel(
        content: [
          .text(ChatMessageTextContent(projectRoot: nil, text: "I can help you with that", attachments: [])),
        ],
        role: .assistant)

      // when
      let messages = sut.apiFormat

      // then
      #expect(messages.count == 1)
      #expect(messages[0].role == Schema.Message.Role.assistant)
      #expect(messages[0].content.count == 1)
      #expect(messages[0].content[0].text == "I can help you with that")
    }

    @MainActor
    @Test("Reasoning content is converted correctly")
    func test_apiFormat_handlesReasoningContent() async throws {
      // given
      let sut = ChatMessageViewModel(
        content: [
          .reasoning(ChatMessageReasoningContent(
            text: "Let me think about this...",
            signature: "reasoning-signature")),
        ],
        role: .assistant)

      // when
      let messages = sut.apiFormat

      // then
      #expect(messages.count == 1)
      #expect(messages[0].role == Schema.Message.Role.assistant)
      #expect(messages[0].content.count == 1)
      #expect(messages[0].content[0].text == "Let me think about this...")
      #expect(messages[0].content[0].signature == "reasoning-signature")
    }

    @MainActor
    @Test("Mixed content types are combined")
    func test_apiFormat_combinesMixedContent() async throws {
      // given
      let sut = ChatMessageViewModel(
        content: [
          .text(ChatMessageTextContent(projectRoot: nil, text: "Here's my response:", attachments: [])),
          .reasoning(ChatMessageReasoningContent(
            text: "Let me think...",
            signature: nil)),
          .text(ChatMessageTextContent(projectRoot: nil, text: "Final answer", attachments: [])),
        ],
        role: .assistant)

      // when
      let messages = sut.apiFormat

      // then
      #expect(messages.count == 1)
      #expect(messages[0].role == Schema.Message.Role.assistant)
      #expect(messages[0].content.count == 3)
      #expect(messages[0].content[0].text == "Here's my response:")
      #expect(messages[0].content[1].text == "Let me think...")
      #expect(messages[0].content[2].text == "Final answer")
    }
  }
}
