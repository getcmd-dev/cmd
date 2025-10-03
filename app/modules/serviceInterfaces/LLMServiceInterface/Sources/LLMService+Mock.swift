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
  public init(activeModels: [LLMFoundation.LLMModelInfo] = []) {
    mutableActiveModels = .init(activeModels)
  }

  public var mutableActiveModels: CurrentValueSubject<[LLMFoundation.LLMModelInfo], Never>

  public var onSendMessage: (@Sendable (
    [Schema.Message],
    [any Tool],
    LLMModelInfo,
    ChatMode,
    ChatContext,
    (UpdateStream) -> Void)
  async throws -> SendMessageResponse)?

  public var onNameConversation: (@Sendable (String) async throws -> String)?

  public var onSummarizeConversation: (@Sendable ([Schema.Message], LLMModelInfo) async throws -> String)?

  public var onListModelsAvailable: (@Sendable (LLMProvider) -> [LLMModel])?

  public var onRefetchModelsAvailable: (@Sendable (LLMProvider, Settings.LLMProviderSettings) async throws -> [LLMModel])?

  public var onGetModel: (@Sendable (String) async throws -> LLMModel?)?

  public var onGetModelInfo: (@Sendable (String) -> LLMModelInfo?)?

  public var onGetModelSync: (@Sendable (String) -> LLMModel?)?

  public var onProviderForModel: (@Sendable (LLMModelInfo) -> LLMProvider?)?

  public var onLowTierModel: (@Sendable () -> LLMModel?)?

  public var activeModels: ReadonlyCurrentValueSubject<[LLMFoundation.LLMModelInfo], Never> {
    mutableActiveModels.readonly()
  }

  // MARK: - LLMService

  public func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool],
    model: LLMModelInfo,
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
    model: LLMModelInfo)
    async throws -> String
  {
    try await onSummarizeConversation?(messageHistory, model) ?? "Mock conversation summary"
  }

  public func modelsAvailable(for provider: LLMProvider) -> [LLMModel] {
    onListModelsAvailable?(provider) ?? []
  }

  public func refetchModelsAvailable(
    for provider: LLMProvider,
    newSettings: Settings.LLMProviderSettings)
    async throws -> [LLMModel]
  {
    try await onRefetchModelsAvailable?(provider, newSettings) ?? modelsAvailable(for: provider)
  }

  public func getModel(by providerModelId: String) -> LLMModel? {
    onGetModelSync?(providerModelId)
  }

  public func getModelInfo(by modelInfoId: ModelInfoId) -> LLMModelInfo? {
    onGetModelInfo?(modelInfoId)
  }

  public func provider(for model: LLMModelInfo) -> LLMProvider? {
    onProviderForModel?(model)
  }

  public func lowTierModel() -> LLMModel? {
    onLowTierModel?()
  }

}
#endif
