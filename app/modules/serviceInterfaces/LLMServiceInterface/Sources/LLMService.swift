// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import ConcurrencyFoundation
import Foundation
import LLMFoundation
import LocalServerServiceInterface
import SettingsServiceInterface
import ToolFoundation

/// Note: this stream of update replays all past updates when enumerated (including for the wrapped array)
public typealias UpdateStream = CurrentValueStream<[CurrentValueStream<AssistantMessage>]>

// MARK: - ChatContext

public protocol ChatContext: Sendable {
  /// When a tool that is not read-only runs, this function will be called before.
  func prepareToExecute(writingToolUse: any ToolUse) /// Returns whether the tool use needs user's approval.
    async
  func needsApproval(for toolUse: any ToolUse) async -> Bool
  /// Request user approval before executing a tool.
  func requestApproval(for toolUse: any ToolUse) async throws

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
    model: LLMModelInfo,
    chatMode: ChatMode,
    context: ChatContext,
    handleUpdateStream: (UpdateStream) -> Void)
    async throws -> SendMessageResponse

  /// Generate a title for a conversation based on the first message.
  func nameConversation(firstMessage: String) async throws -> String

  /// Generate a summary of a conversation based on the message history.
  func summarizeConversation(messageHistory: [Schema.Message], model: LLMModelInfo) async throws -> String

  /// Returns the list of available models for the specified provider.
  ///
  /// - Parameter provider: The LLM provider to get models for.
  /// - Returns: An array of available models for the provider.
  func modelsAvailable(for provider: LLMProvider) -> [LLMModel]

  /// Refetches and returns the list of available models for the specified provider with new settings.
  ///
  /// - Parameters:
  ///   - provider: The LLM provider to refetch models for.
  ///   - newSettings: The updated provider settings to use when fetching models.
  /// - Returns: An array of newly fetched models for the provider.
  /// - Throws: An error if the models cannot be fetched.
  func refetchModelsAvailable(for provider: LLMProvider, newSettings: Settings.LLMProviderSettings) async throws -> [LLMModel]

  /// Retrieves a model by its provider-specific model identifier.
  ///
  /// - Parameter providerModelId: The provider-specific identifier for the model.
  /// - Returns: The model if found, otherwise nil.
  func getModel(by providerModelId: String) -> LLMModel?

  /// Retrieves model information by its model info identifier.
  ///
  /// - Parameter modelInfoId: The unique identifier for the model info.
  /// - Returns: The model information if found, otherwise nil.
  func getModelInfo(by modelInfoId: ModelInfoId) -> LLMModelInfo?

  /// Determines which provider is associated with the given model.
  ///
  /// - Parameter model: The model information to find the provider for.
  /// - Returns: The provider that owns the model, or nil if not found.
  func provider(for model: LLMModelInfo) -> LLMProvider?

  /// A read-only subject that publishes the currently active models.
  ///
  /// This provides reactive updates whenever the set of active models changes.
  var activeModels: ReadonlyCurrentValueSubject<[LLMModelInfo], Never> { get }

  /// Returns the low tier model from configured providers with the cheapest input cost.
  /// Low tier models are suitable for simple queries that favor speed & low cost over accuracy.
  func lowTierModel() -> LLMModel?
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
