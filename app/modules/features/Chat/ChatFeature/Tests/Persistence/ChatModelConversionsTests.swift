// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import ChatServiceInterface
import Foundation
import SwiftTesting
import Testing
@testable import ChatFeature

// MARK: - ChatModelConversionsTests

struct ChatModelConversionsTests {

  @MainActor
  @Test("test model creation and conversion")
  func testModelCreationAndConversion() async {
    // Test ChatThreadViewModel to ChatThreadModel conversion
    let originalTab = ChatThreadViewModel(name: "Test Tab")
    let persistentModel = originalTab.persistentModel

    #expect(persistentModel.name == "Test Tab")
    #expect(persistentModel.id == originalTab.id)

    // Test ChatThreadModel to ChatThreadViewModel conversion
    let loadedTab = ChatThreadViewModel(from: persistentModel)
    #expect(loadedTab.name == "Test Tab")
    #expect(loadedTab.messages.isEmpty)
    #expect(loadedTab.events.isEmpty)
  }

  @MainActor
  @Test("test chat message model conversion")
  func testChatMessageModelConversion() throws {
    let textContent = ChatMessageTextContent(text: "Hello world", isStreaming: false)
    let message = ChatMessageViewModel(content: [.text(textContent)], role: .user)

    // Convert to persistent model
    let persistentMessage = message.persistentModel
    #expect(persistentMessage.role == .user)
    #expect(persistentMessage.content.count == 1)

    // Test content conversion
    let persistentContent = try #require(persistentMessage.content.first)
    #expect(persistentContent.asText?.text == "Hello world")
  }
}

extension ChatMessageContentModel {
  var asText: ChatMessageTextContentModel? {
    guard case .text(let textContent) = self else { return nil }
    return textContent
  }
}
