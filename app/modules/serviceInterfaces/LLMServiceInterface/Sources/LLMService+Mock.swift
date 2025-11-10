// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import LLMFoundation
import LocalServerServiceInterface
import SettingsServiceInterface
import ThreadSafe
import ToolFoundation

#if DEBUG
@ThreadSafe
public final class MockLLMService: LLMService {
  public init(activeModels: [AIModel] = [], availableModels: [AIModel] = []) {
    _activeModels = .init(activeModels)
    _availableModels = .init(availableModels)
  }

  public var _availableModels: CurrentValueSubject<[AIModel], Never>
  public var _activeModels: CurrentValueSubject<[AIModel], Never>

  public var onSendMessage: (@Sendable (
    [Schema.Message],
    [any Tool],
    AIModel,
    ChatMode,
    ChatContext,
    (UpdateStream) -> Void)
  async throws -> SendMessageResponse)?

  public var onPrompt: (@Sendable (String, String?, AIModel) async throws -> String?)?

  public var onSummarizeConversation: (@Sendable ([Schema.Message], AIModel) async throws -> SummarizeConversationResponse)?

  public var onListModelsAvailable: (@Sendable (AIProvider) -> [AIProviderModel])?

  public var onRefetchModelsAvailable: (@Sendable (AIProvider, Settings.AIProviderSettings) async throws -> [AIProviderModel])?

  public var onGetModelInfo: (@Sendable (String) -> AIModel?)?

  public var onGetModel: (@Sendable (String) -> AIProviderModel?)?

  public var onProviderForModel: (@Sendable (AIModel) -> AIProvider?)?

  public var onLowTierModel: (@Sendable () -> AIProviderModel?)?

  public var availableModels: ReadonlyCurrentValueSubject<[AIModel]> { _availableModels.readonly() }

  public var activeModels: ReadonlyCurrentValueSubject<[AIModel]> {
    _activeModels.readonly()
  }

  public func provider(for model: AIModel) -> ReadonlyCurrentValueSubject<AIProvider?> {
    .just(onProviderForModel?(model))
  }

  public func getModelInfo(by modelInfoId: AIModelID) -> ReadonlyCurrentValueSubject<AIModel?> {
    .just(onGetModelInfo?(modelInfoId))
  }

  public func getModel(by providerModelId: String) -> ReadonlyCurrentValueSubject<AIProviderModel?> {
    .just(onGetModel?(providerModelId))
  }

  public func modelsAvailable(for provider: AIProvider)
    -> ReadonlyCurrentValueSubject<[AIProviderModel]>
  {
    .just(onListModelsAvailable?(provider) ?? [])
  }

  // MARK: - LLMService

  public func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool],
    model: AIModel,
    chatMode: ChatMode,
    context: any ChatContext,
    handleUpdateStream: (UpdateStream) -> Void)
    async throws -> SendMessageResponse
  {
    try await onSendMessage?(messageHistory, tools, model, chatMode, context, handleUpdateStream)
      ?? SendMessageResponse(newMessages: [], usageInfo: nil)
  }

  public func prompt(_ prompt: String, system: String?, model: AIModel) async throws -> String? {
    try await onPrompt?(prompt, system, model)
  }

  public func summarizeConversation(
    messageHistory: [Schema.Message],
    model: AIModel)
    async throws -> SummarizeConversationResponse
  {
    try await onSummarizeConversation?(messageHistory, model) ?? SummarizeConversationResponse(
      summary: "Mock conversation summary",
      usageInfo: nil)
  }

  public func modelsAvailable(for provider: AIProvider) -> [AIProviderModel] {
    onListModelsAvailable?(provider) ?? []
  }

  public func refetchModelsAvailable(
    for provider: AIProvider,
    newSettings: Settings.AIProviderSettings)
    async throws -> [AIProviderModel]
  {
    try await onRefetchModelsAvailable?(provider, newSettings) ?? modelsAvailable(for: provider)
  }

  public func lowTierModel() -> AIProviderModel? {
    onLowTierModel?()
  }

}
#endif
