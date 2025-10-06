// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import LLMFoundation
import SettingsServiceInterface
import ThreadSafe
@testable import LLMService

@ThreadSafe
final class MockAIModelsManager: AIModelsManagerProtocol {
  init(activeModels: [AIModel] = [], availableModels: [AIModel] = []) {
    _activeModels = .init(activeModels)
    _availableModels = .init(availableModels)
    setDefaultValues()
  }

  var onModelsAvailableForProvider: @Sendable (AIProvider) -> ReadonlyCurrentValueSubject<[AIProviderModel], Never> = { _ in
    .just([])
  }

  var onRefetchModelsAvailableForProvider: @Sendable (AIProvider, Settings.AIProviderSettings) async throws
    -> [AIProviderModel] = { _, _ in [] }

  var onGetModelByProviderModelId: @Sendable (String) -> ReadonlyCurrentValueSubject<AIProviderModel?, Never> = { _ in
    .just(nil)
  }

  var onGetModelInfoById: @Sendable (AIModelID) -> ReadonlyCurrentValueSubject<AIModel?, Never> = { _ in .just(nil) }
  var onProviderForModel: @Sendable (AIModel) -> ReadonlyCurrentValueSubject<AIProvider?, Never> = { _ in .just(nil) }

  let _activeModels: CurrentValueSubject<[AIModel], Never>
  let _availableModels: CurrentValueSubject<[AIModel], Never>

  var availableModels: ReadonlyCurrentValueSubject<[AIModel], Never> {
    _availableModels.readonly()
  }

  var activeModels: ReadonlyCurrentValueSubject<[AIModel], Never> {
    _activeModels.readonly()
  }

  func provider(for model: AIModel) -> ReadonlyCurrentValueSubject<AIProvider?, Never> {
    onProviderForModel(model)
  }

  func modelsAvailable(for provider: AIProvider) -> ReadonlyCurrentValueSubject<[AIProviderModel], Never> {
    onModelsAvailableForProvider(provider)
  }

  func getModel(by providerModelId: String) -> ReadonlyCurrentValueSubject<AIProviderModel?, Never> {
    onGetModelByProviderModelId(providerModelId)
  }

  func getModelInfo(by modelId: AIModelID) -> ReadonlyCurrentValueSubject<AIModel?, Never> {
    onGetModelInfoById(modelId)
  }

  func refetchModelsAvailable(
    for provider: AIProvider,
    newSettings: Settings.AIProviderSettings)
    async throws -> [AIProviderModel]
  {
    try await onRefetchModelsAvailableForProvider(provider, newSettings)
  }

  private var modelsByProviders = [AIProvider: [AIProviderModel]]()

  /// Initialize the mock with some reasonable default values that should work for most cases.
  private func setDefaultValues() {
    modelsByProviders = [
      .anthropic: [
        .init(providerId: "claude-sonnet-4-5-20250929", provider: .anthropic, modelInfo: .claudeSonnet),
        .init(providerId: "claude-opus-4-1-20250805", provider: .anthropic, modelInfo: .claudeOpus),
        .init(providerId: "claude-3-5-haiku-latest", provider: .anthropic, modelInfo: .claudeHaiku_3_5),
      ],
      .openAI: [
        .init(providerId: "gpt-5-2025-08-07", provider: .openAI, modelInfo: .gpt),
        .init(providerId: "gpt-5-mini-2025-08-07", provider: .openAI, modelInfo: .gpt_turbo),
      ],
      .openRouter: [
        .init(providerId: "anthropic/claude-sonnet-4.5", provider: .anthropic, modelInfo: .claudeSonnet),
        .init(providerId: "anthropic/claude-opus-4.1", provider: .anthropic, modelInfo: .claudeOpus),
        .init(providerId: "anthropic/claude-3.5-haiku", provider: .anthropic, modelInfo: .claudeHaiku_3_5),
        .init(providerId: "openai/gpt-5-2025-08-07", provider: .openAI, modelInfo: .gpt),
        .init(providerId: "openai/gpt-5-mini-2025-08-07", provider: .openAI, modelInfo: .gpt_turbo),
      ],
    ]

    onModelsAvailableForProvider = { [weak self] provider in .just(self?.modelsByProviders[provider] ?? []) }
    onRefetchModelsAvailableForProvider = { [weak self] provider, _ in self?.modelsByProviders[provider] ?? [] }
    onGetModelByProviderModelId = { [weak self] providerModelId in
      .just(self?.modelsByProviders.values.flatMap(\.self).first(where: { $0.id == providerModelId }))
    }
    onGetModelInfoById = { [weak self] id in
      .just(self?.modelsByProviders.values.flatMap(\.self).first(where: { $0.modelInfo.id == id })?.modelInfo)
    }
    onProviderForModel = { [weak self] modelInfo in
      .just(self?.modelsByProviders.filter({ $0.value.contains(where: { $0.modelInfo.id == modelInfo.id }) }).map(\.key)
        .sorted(by: { a, b in a.name < b.name }).first)
    }
  }

}
