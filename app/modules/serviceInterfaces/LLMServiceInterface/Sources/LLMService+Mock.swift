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
    public func provider(for model: LLMFoundation.AIModel) -> ConcurrencyFoundation.ReadonlyCurrentValueSubject<LLMFoundation.AIProvider?, Never> {
        .just(provider(for: model))
    }
    
    public func getModelInfo(by modelInfoId: AIModelID) -> ReadonlyCurrentValueSubject<AIModel?, Never> {
        .just(getModelInfo(by: modelInfoId))
    }
    
    public func getModel(by providerModelId: String) -> ReadonlyCurrentValueSubject<AIProviderModel?, Never> {
        .just(getModel(by: providerModelId))
    }
    
    public var _availableModels: CurrentValueSubject<[LLMFoundation.AIModel], Never>
    public var availableModels: ReadonlyCurrentValueSubject<[LLMFoundation.AIModel], Never> { _availableModels.readonly() }
    
  public init(activeModels: [AIModel] = [], availableModels: [AIModel] = []) {
      
    _activeModels = .init(activeModels)
      _availableModels = .init(availableModels)
  }

  public var _activeModels: CurrentValueSubject<[LLMFoundation.AIModel], Never>

  public var onSendMessage: (@Sendable (
    [Schema.Message],
    [any Tool],
    AIModel,
    ChatMode,
    ChatContext,
    (UpdateStream) -> Void)
  async throws -> SendMessageResponse)?

  public var onNameConversation: (@Sendable (String) async throws -> String)?

  public var onSummarizeConversation: (@Sendable ([Schema.Message], AIModel) async throws -> String)?

  public var onListModelsAvailable: (@Sendable (AIProvider) -> [AIProviderModel])?

  public var onRefetchModelsAvailable: (@Sendable (AIProvider, Settings.AIProviderSettings) async throws -> [AIProviderModel])?

  public var onGetModel: (@Sendable (String) async throws -> AIProviderModel?)?

  public var onGetModelInfo: (@Sendable (String) -> AIModel?)?

  public var onGetModelSync: (@Sendable (String) -> AIProviderModel?)?

  public var onProviderForModel: (@Sendable (AIModel) -> AIProvider?)?

  public var onLowTierModel: (@Sendable () -> AIProviderModel?)?

  public var activeModels: ReadonlyCurrentValueSubject<[LLMFoundation.AIModel], Never> {
    _activeModels.readonly()
  }

  public func modelsAvailable(for _: LLMFoundation
    .AIProvider)
    -> ReadonlyCurrentValueSubject<[LLMFoundation.AIProviderModel], Never>
  {
    CurrentValueSubject([]).readonly()
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

  public func nameConversation(firstMessage: String) async throws -> String {
    try await onNameConversation?(firstMessage) ?? "Unnamed Conversation"
  }

  public func summarizeConversation(
    messageHistory: [Schema.Message],
    model: AIModel)
    async throws -> String
  {
    try await onSummarizeConversation?(messageHistory, model) ?? "Mock conversation summary"
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

  public func getModel(by providerModelId: String) -> AIProviderModel? {
    onGetModelSync?(providerModelId)
  }

  public func getModelInfo(by modelInfoId: AIModelID) -> AIModel? {
    onGetModelInfo?(modelInfoId)
  }

  public func provider(for model: AIModel) -> AIProvider? {
    onProviderForModel?(model)
  }

  public func lowTierModel() -> AIProviderModel? {
    onLowTierModel?()
  }

}
#endif
