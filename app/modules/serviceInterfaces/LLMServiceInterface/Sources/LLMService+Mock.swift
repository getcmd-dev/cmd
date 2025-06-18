// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LLMFoundation
import ServerServiceInterface
import ThreadSafe
import ToolFoundation

#if DEBUG
@ThreadSafe
public final class MockLLMService: LLMService {

  public init() { }

  public var onSendMessage: (@Sendable (
    [Schema.Message],
    [any Tool],
    LLMModel,
    ChatContext,
    (UpdateStream) -> Void)
    -> [AssistantMessage])?

  public var onNameConversation: (@Sendable (String) async throws -> String)?

  // MARK: - LLMService

  public func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool],
    model: LLMModel,
    context: any ChatContext,
    handleUpdateStream: (UpdateStream) -> Void)
    async throws -> [AssistantMessage]
  {
    if let onSendMessage {
      return onSendMessage(messageHistory, tools, model, context, handleUpdateStream)
    }

    // Default implementation returning empty array if no handler is set
    return []
  }

  public func nameConversation(firstMessage: String) async throws -> String {
    if let onNameConversation {
      return try await onNameConversation(firstMessage)
    }
    return "Unnamed Conversation"
  }

}
#endif
