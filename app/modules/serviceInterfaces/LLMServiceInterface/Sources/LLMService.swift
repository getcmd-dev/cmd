// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import ConcurrencyFoundation
import Foundation
import LLMFoundation
import ServerServiceInterface
import ToolFoundation

public typealias UpdateStream = CurrentValueStream<[CurrentValueStream<AssistantMessage>]>

// MARK: - ChatContext

public protocol ChatContext: Sendable {
  /// When a tool that is not read-only runs, this function will be called before.
  var prepareForWriteToolUse: @Sendable () async -> Void { get }
  /// Request user approval before executing a tool.
  var requestToolApproval: @Sendable (any ToolUse) async throws -> Void { get }

  var toolExecutionContext: ToolExecutionContext { get }
}

// MARK: - LLMService

public protocol LLMService: Sendable {
  /// Send a message and wait for responses from the assistant
  ///
  /// - Returns: A response containing the assistant's messages and usage information (token counts, costs, etc.) if available.
  /// - Parameters:
  ///   - messageHistory: The historical context of all messages in the conversation. The last message is expected to be the last one sent by the user.
  ///   - tools: The tools available to the assistant.
  ///   - model: The model to use for the assistant.
  ///   - context: The context in which the message is sent, providing information and hooks for the assistant to use.
  ///   - handleUpdateStream: A callback called synchronously with a stream that will broadcast updates about received messages. This can be usefull if you want to display the messages as they are streamed.
  func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool],
    model: LLMModel,
    chatMode: ChatMode,
    context: ChatContext,
    handleUpdateStream: (UpdateStream) -> Void)
    async throws -> SendMessageResponse

  /// Generate a title for a conversation based on the first message.
  func nameConversation(firstMessage: String) async throws -> String

  /// Generate a summary of a conversation based on the message history.
  func summarizeConversation(messageHistory: [Schema.Message], model: LLMModel) async throws -> String
}

public typealias LLMUsageInfo = Schema.ResponseUsage

// MARK: - SendMessageResponse

public struct SendMessageResponse: Sendable {
  public let newMessages: [AssistantMessage]
  public let usageInfo: LLMUsageInfo?

  public init(newMessages: [AssistantMessage], usageInfo: LLMUsageInfo?) {
    self.newMessages = newMessages
    self.usageInfo = usageInfo
  }
}

// MARK: - LLMServiceError

public enum LLMServiceError: Error {
  case toolUsageDenied(reason: String)
}

// MARK: LocalizedError

extension LLMServiceError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .toolUsageDenied(let reason):
      if reason.isEmpty {
        "User denied permission to execute this tool."
      } else {
        "User denied permission to execute this tool with the following explanation: \(reason)."
      }
    }
  }
}

//
// #if DEBUG
//// TODO: Remove this once tests have been migrated to use the new API.
// extension LLMService {
//  func sendMessage(
//    messageHistory: [Schema.Message],
//    tools: [any Tool],
//    model: LLMModel,
//    chatMode: ChatMode,
//    context: ChatContext,
//    handleUpdateStream: (UpdateStream) -> Void)
//    async throws -> SendMessageResponse
//  {
//    try await sendMessage(
//      messageHistory: messageHistory,
//      tools: tools,
//      model: model,
//      chatMode: chatMode,
//      context: context,
//      handleUpdateStream: handleUpdateStream)
//  }
// }
// #endif
