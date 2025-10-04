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
  init(activeModels: [AIModel] = []) {
    mutableActiveModels = .init(activeModels)
    setDefaultValues()
  }

  var onModelsAvailableForProvider: @Sendable (AIProvider) -> [AIProviderModel] = { _ in [] }

  var onRefetchModelsAvailableForProvider: @Sendable (AIProvider, Settings.AIProviderSettings) async throws
    -> [AIProviderModel] = { _, _ in [] }

  var onGetModelByProviderModelId: @Sendable (String) -> AIProviderModel? = { _ in nil }

  var onGetModelInfoById: @Sendable (ModelInfoId) -> AIModel? = { _ in nil }
  var onProviderForModel: @Sendable (AIModel) -> AIProvider? = { _ in nil }

  let mutableActiveModels: CurrentValueSubject<[AIModel], Never>

  var activeModels: ReadonlyCurrentValueSubject<[AIModel], Never> {
    mutableActiveModels.readonly()
  }

  func modelsAvailable(for provider: AIProvider) -> [AIProviderModel] {
    onModelsAvailableForProvider(provider)
  }

  func refetchModelsAvailable(
    for provider: AIProvider,
    newSettings: Settings.AIProviderSettings)
    async throws -> [AIProviderModel]
  {
    try await onRefetchModelsAvailableForProvider(provider, newSettings)
  }

  func getModel(by providerModelId: String) -> AIProviderModel? {
    onGetModelByProviderModelId(providerModelId)
  }

  func getModelInfo(by id: ModelInfoId) -> AIModel? {
    onGetModelInfoById(id)
  }

  func provider(for model: AIModel) -> AIProvider? {
    onProviderForModel(model)
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

    onModelsAvailableForProvider = { [weak self] provider in self?.modelsByProviders[provider] ?? [] }
    onRefetchModelsAvailableForProvider = { [weak self] provider, _ in self?.modelsByProviders[provider] ?? [] }
    onGetModelByProviderModelId = { [weak self] providerModelId in
      self?.modelsByProviders.values.flatMap(\.self).first(where: { $0.id == providerModelId })
    }
    onGetModelInfoById = { [weak self] id in
      self?.modelsByProviders.values.flatMap(\.self).first(where: { $0.modelInfo.id == id })?.modelInfo
    }
    onProviderForModel = { [weak self] modelInfo in
      self?.modelsByProviders.filter({ $0.value.contains(where: { $0.modelInfo.id == modelInfo.id }) }).map(\.key)
        .sorted(by: { a, b in a.name < b.name }).first
    }
  }

}
