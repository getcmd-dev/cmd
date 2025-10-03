// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import LLMFoundation
import SettingsServiceInterface
import ThreadSafe
@testable import LLMService

@ThreadSafe
final class MockLLMModelManager: LLMModelManagerProtocol {
  init(activeModels: [LLMModelInfo] = []) {
    mutableActiveModels = .init(activeModels)
    setDefaultValues()
  }

  var onModelsAvailableForProvider: @Sendable (LLMProvider) -> [LLMModel] = { _ in [] }

  var onRefetchModelsAvailableForProvider: @Sendable (LLMProvider, Settings.LLMProviderSettings) async throws
    -> [LLMModel] = { _, _ in [] }

  var onGetModelByProviderModelId: @Sendable (String) -> LLMModel? = { _ in nil }

  var onGetModelInfoById: @Sendable (ModelInfoId) -> LLMModelInfo? = { _ in nil }
  var onProviderForModel: @Sendable (LLMModelInfo) -> LLMProvider? = { _ in nil }

  let mutableActiveModels: CurrentValueSubject<[LLMModelInfo], Never>

  var activeModels: ReadonlyCurrentValueSubject<[LLMModelInfo], Never> {
    mutableActiveModels.readonly()
  }

  func modelsAvailable(for provider: LLMProvider) -> [LLMModel] {
    onModelsAvailableForProvider(provider)
  }

  func refetchModelsAvailable(for provider: LLMProvider, newSettings: Settings.LLMProviderSettings) async throws -> [LLMModel] {
    try await onRefetchModelsAvailableForProvider(provider, newSettings)
  }

  func getModel(by providerModelId: String) -> LLMModel? {
    onGetModelByProviderModelId(providerModelId)
  }

  func getModelInfo(by id: ModelInfoId) -> LLMModelInfo? {
    onGetModelInfoById(id)
  }

  func provider(for model: LLMModelInfo) -> LLMProvider? {
    onProviderForModel(model)
  }

  private var modelsByProviders = [LLMProvider: [LLMModel]]()

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
