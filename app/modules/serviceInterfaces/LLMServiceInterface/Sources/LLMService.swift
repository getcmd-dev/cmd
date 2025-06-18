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
  /// The path to the project that is being worked on.
  var project: URL? { get }
  /// The root of the project that is being worked on.
  /// For a Swift package this is the same as the project. For an xcodeproj this is the containing directory.
  var projectRoot: URL? { get }

  /// When a tool that is not read-only runs, this function will be called before.
  var prepareForWriteToolUse: @Sendable () async -> Void { get }
  /// Request user approval before executing a tool.
  var requestToolApproval: @Sendable (any ToolUse) async throws -> Void { get }
  /// Which chat mode applies to the current context.
  var chatMode: ChatMode { get }
}

// MARK: - LLMService

public protocol LLMService: Sendable {
  /// Send a message and wait for responses from the assistant
  func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool],
    model: LLMModel,
    context: ChatContext,
    handleUpdateStream: (UpdateStream) -> Void)
    async throws -> [AssistantMessage]

  /// Generate a title for a conversation based on the first message.
  func nameConversation(firstMessage: String) async throws -> String
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

#if DEBUG
// TODO: Remove this once tests have been migrated to use the new API.
extension LLMService {
  func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool],
    model: LLMModel,
    context: ChatContext,
    handleUpdateStream: (UpdateStream) -> Void)
    async throws -> [AssistantMessage]
  {
    try await sendMessage(
      messageHistory: messageHistory,
      tools: tools,
      model: model,
      context: context,
      handleUpdateStream: handleUpdateStream)
  }
}
#endif
