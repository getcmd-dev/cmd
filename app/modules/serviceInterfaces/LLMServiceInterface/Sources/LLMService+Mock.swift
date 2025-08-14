// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LLMFoundation
import LocalServerServiceInterface
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
    ChatMode,
    ChatContext,
    (UpdateStream) -> Void)
  async throws -> SendMessageResponse)?

  public var onNameConversation: (@Sendable (String) async throws -> String)?

  public var onSummarizeConversation: (@Sendable ([Schema.Message], LLMModel) async throws -> String)?

  // MARK: - LLMService

  public func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool],
    model: LLMModel,
    chatMode: ChatMode,
    context: any ChatContext,
    handleUpdateStream: (UpdateStream) -> Void)
    async throws -> SendMessageResponse
  {
    if let onSendMessage {
      return try await onSendMessage(messageHistory, tools, model, chatMode, context, handleUpdateStream)
    }

    // Default implementation returning empty array if no handler is set
    return SendMessageResponse(newMessages: [], usageInfo: nil)
  }

  public func nameConversation(firstMessage: String) async throws -> String {
    if let onNameConversation {
      return try await onNameConversation(firstMessage)
    }
    return "Unnamed Conversation"
  }

  public func summarizeConversation(
    messageHistory: [Schema.Message],
    model: LLMModel)
    async throws -> String
  {
    if let onSummarizeConversation {
      return try await onSummarizeConversation(messageHistory, model)
    }
    return "Mock conversation summary"
  }

}
#endif
