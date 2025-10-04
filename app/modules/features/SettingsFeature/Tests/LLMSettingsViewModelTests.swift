// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Dependencies
import DependenciesTestSupport
import Foundation
import LLMFoundation
import LLMServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
@testable import SettingsFeature

// MARK: - LLMSettingsViewModelTests

@MainActor
@Suite("LLMSettingsViewModelTests", .dependencies { $0.setDefaulfMockValues() })
class LLMSettingsViewModelTests {

  // MARK: - Initialization Tests

  @Test("initializes with settings from service", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
    ]
    let enabledModels: [AIModelID] = ["model1", "model2"]
    let reasoningModels: [AIModelID: LLMReasoningSetting] = ["model1": .init(isEnabled: true)]
    let preferedProviders: [AIModelID: AIProvider] = ["model1": .anthropic]

    let initialSettings = SettingsServiceInterface.Settings(
      preferedProviders: preferedProviders,
      llmProviderSettings: providerSettings,
      enabledModels: enabledModels,
      reasoningModels: reasoningModels)

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = MockLLMService()
  })
  func initializationWithSettings() {
    // given
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
    ]
    let enabledModels: [AIModelID] = ["model1", "model2"]
    let reasoningModels: [AIModelID: LLMReasoningSetting] = ["model1": .init(isEnabled: true)]

    // when
    let sut = LLMSettingsViewModel()

    // then
    #expect(sut.providerSettings == providerSettings)
    #expect(sut.enabledModels == enabledModels)
    #expect(sut.reasoningModels == reasoningModels)
  }

  @Test("observes live settings updates")
  func liveSettingsUpdates() async throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)

    let sut = LLMSettingsViewModel()

    // when
    let newProviderSettings: [AIProvider: AIProviderSettings] = [
      .openAI: AIProviderSettings(apiKey: "new-key", baseUrl: nil, executable: nil, createdOrder: 1),
    ]
    let newSettings = SettingsServiceInterface.Settings(llmProviderSettings: newProviderSettings)
    mockSettingsService.update(to: newSettings)

    // then
    try await sut.wait(for: \.providerSettings, toBe: newProviderSettings)
    #expect(sut.providerSettings == newProviderSettings)
  }

  // MARK: - Enable/Disable Model Tests

  @Test("enable model adds to enabled models and updates settings")
  func enableModel() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model = AIModel.claudeHaiku_3_5

    let sut = LLMSettingsViewModel()

    // when
    sut.enable(model: model)

    // then
    #expect(sut.enabledModels.contains(model.id))
    #expect(mockSettingsService.value(for: \.enabledModels).contains(model.id))
  }

  @Test("disable model removes from enabled models and updates settings", .dependencies {
    let model = AIModel.claudeHaiku_3_5
    let initialSettings = SettingsServiceInterface.Settings(
      enabledModels: [model.id, "other-model"])

    $0.settingsService = MockSettingsService(initialSettings)
  })
  func disableModel() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model = AIModel.claudeHaiku_3_5

    let sut = LLMSettingsViewModel()

    // when
    sut.disable(model: model)

    // then
    #expect(!sut.enabledModels.contains(model.id))
    #expect(!mockSettingsService.value(for: \.enabledModels).contains(model.id))
    #expect(mockSettingsService.value(for: \.enabledModels).contains("other-model"))
  }

  @Test("isActive binding returns correct state", .dependencies {
    let model = AIModel.claudeHaiku_3_5
    let initialSettings = SettingsServiceInterface.Settings(enabledModels: [model.id])

    $0.settingsService = MockSettingsService(initialSettings)
  })
  func isActiveBindingGetter() {
    // given
    let model = AIModel.claudeHaiku_3_5
    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.isActive(for: model)

    // then
    #expect(binding.wrappedValue == true)
  }

  @Test("isActive binding setter enables model")
  func isActiveBindingSetterEnables() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model = AIModel.claudeHaiku_3_5

    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.isActive(for: model)
    binding.wrappedValue = true

    // then
    #expect(sut.enabledModels.contains(model.id))
    #expect(mockSettingsService.value(for: \.enabledModels).contains(model.id))
  }

  @Test("isActive binding setter disables model", .dependencies {
    let model = AIModel.claudeHaiku_3_5
    let initialSettings = SettingsServiceInterface.Settings(enabledModels: [model.id])

    $0.settingsService = MockSettingsService(initialSettings)
  })
  func isActiveBindingSetterDisables() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model = AIModel.claudeHaiku_3_5

    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.isActive(for: model)
    binding.wrappedValue = false

    // then
    #expect(!sut.enabledModels.contains(model.id))
    #expect(!mockSettingsService.value(for: \.enabledModels).contains(model.id))
  }

  // MARK: - Reasoning Tests

  @Test("enable reasoning adds to reasoning models and updates settings")
  func enableReasoning() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model = AIModel.claudeSonnet

    let sut = LLMSettingsViewModel()

    // when
    sut.enableReasoning(for: model)

    // then
    #expect(sut.reasoningModels[model.id]?.isEnabled == true)
    #expect(mockSettingsService.value(for: \.reasoningModels)[model.id]?.isEnabled == true)
  }

  @Test("disable reasoning removes from reasoning models and updates settings", .dependencies {
    let model = AIModel.claudeSonnet
    let initialSettings = SettingsServiceInterface.Settings(
      reasoningModels: [model.id: .init(isEnabled: true)])

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = MockLLMService()
  })
  func disableReasoning() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model = AIModel.claudeSonnet

    let sut = LLMSettingsViewModel()

    // when
    sut.disableReasoning(for: model)

    // then
    #expect(sut.reasoningModels[model.id] == nil)
    #expect(mockSettingsService.value(for: \.reasoningModels)[model.id] == nil)
  }

  @Test("reasoningSetting binding returns nil for non-reasoning model")
  func reasoningSettingBindingNilForNonReasoningModel() {
    // given
    let model = AIModel.claudeHaiku_3_5
    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.reasoningSetting(for: model)

    // then
    #expect(binding == nil)
  }

  @Test("reasoningSetting binding returns correct state for reasoning model", .dependencies {
    let model = AIModel.claudeSonnet
    let initialSettings = SettingsServiceInterface.Settings(
      reasoningModels: [model.id: .init(isEnabled: true)])

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = MockLLMService()
  })
  func reasoningSettingBindingGetter() {
    // given
    let model = AIModel.claudeSonnet
    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.reasoningSetting(for: model)

    // then
    #expect(binding?.wrappedValue.isEnabled == true)
  }

  @Test("reasoningSetting binding setter enables reasoning")
  func reasoningSettingBindingSetterEnables() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model = AIModel.claudeSonnet

    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.reasoningSetting(for: model)
    binding?.wrappedValue = .init(isEnabled: true)

    // then
    #expect(sut.reasoningModels[model.id]?.isEnabled == true)
    #expect(mockSettingsService.value(for: \.reasoningModels)[model.id]?.isEnabled == true)
  }

  @Test("reasoningSetting binding setter disables reasoning", .dependencies {
    let model = AIModel.claudeSonnet
    let initialSettings = SettingsServiceInterface.Settings(
      reasoningModels: [model.id: .init(isEnabled: true)])

    $0.settingsService = MockSettingsService(initialSettings)
  })
  func reasoningSettingBindingSetterDisables() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model = AIModel.claudeSonnet

    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.reasoningSetting(for: model)
    binding?.wrappedValue = .init(isEnabled: false)

    // then
    #expect(sut.reasoningModels[model.id] == nil)
    #expect(mockSettingsService.value(for: \.reasoningModels)[model.id] == nil)
  }

  // MARK: - Provider Settings Tests

  @Test("save provider settings updates settings and refetches models", .dependencies {
    let mockLLMService = MockLLMService()
    let refetchCalled = Atomic(false)
    mockLLMService.onRefetchModelsAvailable = { provider, settings in
      refetchCalled.mutate { $0 = true }
      #expect(provider == .anthropic)
      #expect(settings.apiKey == "new-key")
      return []
    }

    $0.settingsService = MockSettingsService()
    $0.llmService = mockLLMService
  })
  func saveProviderSettings() async throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

    let refetchCalled = Atomic(false)
    mockLLMService.onRefetchModelsAvailable = { provider, settings in
      refetchCalled.mutate { $0 = true }
      #expect(provider == .anthropic)
      #expect(settings.apiKey == "new-key")
      return []
    }

    let sut = LLMSettingsViewModel()
    let newSettings = AIProviderSettings(apiKey: "new-key", baseUrl: nil, executable: nil, createdOrder: 1)

    // when
    sut.save(providerSettings: newSettings, for: .anthropic)

    // Wait for async refetch to complete
    await nextTick()

    // then
    #expect(sut.providerSettings[.anthropic] == newSettings)
    #expect(mockSettingsService.value(for: \.llmProviderSettings)[.anthropic] == newSettings)
    #expect(refetchCalled.value)
  }

  @Test("remove provider updates settings", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
      .openAI: AIProviderSettings(apiKey: "test-key-2", baseUrl: nil, executable: nil, createdOrder: 2),
    ]
    let initialSettings = SettingsServiceInterface.Settings(llmProviderSettings: providerSettings)

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = MockLLMService()
  })
  func removeProvider() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)

    let sut = LLMSettingsViewModel()

    // when
    sut.remove(provider: .anthropic)

    // then
    #expect(sut.providerSettings[.anthropic] == nil)
    #expect(sut.providerSettings[.openAI] != nil)
    #expect(mockSettingsService.value(for: \.llmProviderSettings)[.anthropic] == nil)
    #expect(mockSettingsService.value(for: \.llmProviderSettings)[.openAI] != nil)
  }

  // MARK: - Default Models Tests

  @Test("saves new provider and enables default models")
  func saveNewProviderEnablesDefaultModels() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)

    let models: [AIModel] = [.claudeOpus, .claudeSonnet]
    mockLLMService.onRefetchModelsAvailable = { provider, _ in
      #expect(provider == .anthropic)
      return models.map { .init(
        providerId: provider.name,
        provider: provider,
        modelInfo: $0) }
    }
    mockLLMService.onGetModelInfo = { modelId in
      models.first { $0.id == modelId }
    }
    let hasEnabledModels = expectation(description: "has enabled models")
    mockSettingsService.liveValue(for: \.enabledModels).sink { models in
      if !models.isEmpty { hasEnabledModels.fulfillAtMostOnce() }
    }.store(in: &cancellables)

    let sut = LLMSettingsViewModel()
    let newSettings = AIProviderSettings(apiKey: "new-key", baseUrl: nil, executable: nil, createdOrder: 1)

    // when
    sut.save(providerSettings: newSettings, for: .anthropic)

    try await fulfillment(of: hasEnabledModels)

    // then
    #expect(mockSettingsService.value(for: \.enabledModels).contains(AIModel.claudeOpus.id))
    #expect(mockSettingsService.value(for: \.enabledModels).contains(AIModel.claudeSonnet.id))
  }

  @Test("updates existing provider without enabling default models again", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "old-key", baseUrl: nil, executable: nil, createdOrder: 1),
    ]
    $0.settingsService = MockSettingsService(.init(llmProviderSettings: providerSettings))
  })
  func updateExistingProviderDoesNotEnableDefaultModels() async throws {
    // given
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)

    let hasFetchedNewModels = expectation(description: "has fetched new models")
    mockLLMService.onRefetchModelsAvailable = { provider, _ in
      #expect(provider == .anthropic)
      hasFetchedNewModels.fulfill()
      return []
    }

    let sut = LLMSettingsViewModel()
    let updatedSettings = AIProviderSettings(apiKey: "updated-key", baseUrl: nil, executable: nil, createdOrder: 1)

    // when
    sut.save(providerSettings: updatedSettings, for: .anthropic)

    // Wait for async refetch to complete
    try await fulfillment(of: hasFetchedNewModels)
    await nextTick()

    // then
    #expect(mockSettingsService.value(for: \.enabledModels).isEmpty)
  }

  @Test("does not duplicate already enabled default models", .dependencies {
    $0.settingsService = MockSettingsService(.init(enabledModels: [AIModel.claudeOpus.id]))
  })
  func saveNewProviderDoesNotDuplicateEnabledModels() async throws {
    // given
    let defaultModel = AIModel.claudeOpus

    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)
    let hasFetchedNewModels = expectation(description: "has fetched new models")
    mockLLMService.onRefetchModelsAvailable = { provider, _ in
      #expect(provider == .anthropic)
      hasFetchedNewModels.fulfill()
      return []
    }
    mockLLMService.onGetModelInfo = { modelId in
      modelId == defaultModel.id ? defaultModel : nil
    }

    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)

    let sut = LLMSettingsViewModel()
    let newSettings = AIProviderSettings(apiKey: "new-key", baseUrl: nil, executable: nil, createdOrder: 1)

    // when
    sut.save(providerSettings: newSettings, for: .anthropic)

    // Wait for async refetch to complete
    try await fulfillment(of: hasFetchedNewModels)
    await nextTick()

    // then
    let enabledModels = mockSettingsService.value(for: \.enabledModels)
    let modelCount = enabledModels.filter { $0 == defaultModel.id }.count
    #expect(modelCount == 1)
  }

  // MARK: - Computed Properties Tests

  @Test("availableProviders returns configured providers", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
      .openAI: AIProviderSettings(apiKey: "test-key-2", baseUrl: nil, executable: nil, createdOrder: 2),
    ]
    let initialSettings = SettingsServiceInterface.Settings(llmProviderSettings: providerSettings)

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = MockLLMService()
  })
  func availableProviders() {
    // given
    let sut = LLMSettingsViewModel()

    // when
    let providers = sut.availableProviders

    // then
    #expect(providers.contains(.anthropic))
    #expect(providers.contains(.openAI))
    #expect(providers.count == 2)
  }

  @Test("availableModels returns unique models from all providers", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
      .openAI: AIProviderSettings(apiKey: "test-key-2", baseUrl: nil, executable: nil, createdOrder: 2),
    ]
    let initialSettings = SettingsServiceInterface.Settings(llmProviderSettings: providerSettings)

    let mockLLMService = MockLLMService()
    let model1 = AIModel.claudeHaiku_3_5
    let model2 = AIModel.claudeSonnet

    mockLLMService.onListModelsAvailable = { provider in
      if provider == .anthropic {
        return [AIProviderModel(providerId: model1.id, provider: .anthropic, modelInfo: model1)]
      } else if provider == .openAI {
        return [AIProviderModel(providerId: model2.id, provider: .openAI, modelInfo: model2)]
      }
      return []
    }

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = mockLLMService
  })
  func availableModels() {
    // given
    let model1 = AIModel.claudeHaiku_3_5
    let model2 = AIModel.claudeSonnet
    let sut = LLMSettingsViewModel()

    // when
    let models = sut.availableModels

    // then
    #expect(models.contains(model1))
    #expect(models.contains(model2))
    #expect(models.count == 2)
  }

  @Test("modelsAvailable returns models for specific provider", .dependencies {
    let mockLLMService = MockLLMService()
    let model1 = AIModel.claudeHaiku_3_5
    let anthropicModel = AIProviderModel(providerId: model1.id, provider: .anthropic, modelInfo: model1)

    mockLLMService.onListModelsAvailable = { provider in
      provider == .anthropic ? [anthropicModel] : []
    }

    $0.settingsService = MockSettingsService()
    $0.llmService = mockLLMService
  })
  func modelsAvailable() {
    // given
    let model1 = AIModel.claudeHaiku_3_5
    let sut = LLMSettingsViewModel()

    // when
    let models = sut.modelsAvailable(for: .anthropic)

    // then
    #expect(models.count == 1)
    #expect(models.first?.modelInfo == model1)
  }

  @Test("providersAvailable returns providers that support given model", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
      .openAI: AIProviderSettings(apiKey: "test-key-2", baseUrl: nil, executable: nil, createdOrder: 2),
    ]
    let initialSettings = SettingsServiceInterface.Settings(llmProviderSettings: providerSettings)

    let mockLLMService = MockLLMService()
    let model1 = AIModel.claudeHaiku_3_5

    mockLLMService.onListModelsAvailable = { provider in
      if provider == .anthropic {
        return [AIProviderModel(providerId: model1.id, provider: .anthropic, modelInfo: model1)]
      }
      return []
    }

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = mockLLMService
  })
  func providersAvailable() {
    // given
    let model1 = AIModel.claudeHaiku_3_5
    let sut = LLMSettingsViewModel()

    // when
    let providers = sut.providersAvailable(for: model1)

    // then
    #expect(providers.contains(.anthropic))
    #expect(!providers.contains(.openAI))
    #expect(providers.count == 1)
  }

  @Test("providerForModels getter returns default provider from service", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
    ]
    let initialSettings = SettingsServiceInterface.Settings(llmProviderSettings: providerSettings)

    let mockLLMService = MockLLMService()
    let model1 = AIModel.claudeHaiku_3_5

    mockLLMService.onListModelsAvailable = { provider in
      if provider == .anthropic {
        return [AIProviderModel(providerId: model1.id, provider: .anthropic, modelInfo: model1)]
      }
      return []
    }
    mockLLMService.onProviderForModel = { _ in .anthropic }

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = mockLLMService
  })
  func providerForModelsGetter() {
    // given
    let model1 = AIModel.claudeHaiku_3_5
    let sut = LLMSettingsViewModel()

    // when
    let providerForModels = sut.providerForModels

    // then
    #expect(providerForModels[model1] == .anthropic)
  }

  @Test("providerForModels setter updates preferred providers")
  func providerForModelsSetter() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model1 = AIModel.claudeHaiku_3_5

    let sut = LLMSettingsViewModel()

    // when
    sut.providerForModels = [model1: .openAI]

    // then
    #expect(mockSettingsService.value(for: \.preferedProviders)[model1.id] == .openAI)
  }

  @Test("provider binding returns correct provider", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
    ]
    let initialSettings = SettingsServiceInterface.Settings(llmProviderSettings: providerSettings)

    let mockLLMService = MockLLMService()
    let model1 = AIModel.claudeHaiku_3_5

    mockLLMService.onListModelsAvailable = { provider in
      if provider == .anthropic {
        return [AIProviderModel(providerId: model1.id, provider: .anthropic, modelInfo: model1)]
      }
      return []
    }
    mockLLMService.onProviderForModel = { _ in .anthropic }

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = mockLLMService
  })
  func providerBindingGetter() {
    // given
    let model1 = AIModel.claudeHaiku_3_5
    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.provider(for: model1)

    // then
    #expect(binding.wrappedValue == .anthropic)
  }

  @Test("provider binding setter updates preferred provider")
  func providerBindingSetter() throws {
    // given
    @Dependency(\.settingsService) var settingsService
    let mockSettingsService = try #require(settingsService as? MockSettingsService)
    let model1 = AIModel.claudeHaiku_3_5

    let sut = LLMSettingsViewModel()

    // when
    let binding = sut.provider(for: model1)
    binding.wrappedValue = AIProvider.openAI

    // then
    #expect(mockSettingsService.value(for: \.preferedProviders)[model1.id] == .openAI)
  }

  @Test("providerForModels respects preferred providers over defaults", .dependencies {
    let providerSettings: [AIProvider: AIProviderSettings] = [
      .anthropic: AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1),
      .openAI: AIProviderSettings(apiKey: "test-key-2", baseUrl: nil, executable: nil, createdOrder: 2),
    ]
    let model1 = AIModel.claudeHaiku_3_5
    let preferedProviders: [AIModelID: AIProvider] = [model1.id: .openAI]

    let initialSettings = SettingsServiceInterface.Settings(
      preferedProviders: preferedProviders,
      llmProviderSettings: providerSettings)

    let mockLLMService = MockLLMService()
    mockLLMService.onListModelsAvailable = { provider in
      if provider == .anthropic {
        return [AIProviderModel(providerId: model1.id, provider: .anthropic, modelInfo: model1)]
      }
      return []
    }
    mockLLMService.onProviderForModel = { _ in .anthropic }
    mockLLMService.onGetModelInfo = { id in id == model1.id ? model1 : nil }

    $0.settingsService = MockSettingsService(initialSettings)
    $0.llmService = mockLLMService
  })
  func providerForModelsPrefersUserChoice() {
    // given
    let model1 = AIModel.claudeHaiku_3_5
    let sut = LLMSettingsViewModel()

    // when
    let providerForModels = sut.providerForModels

    // then
    #expect(providerForModels[model1] == .openAI)
  }

  private var cancellables = Set<AnyCancellable>()

}

// MARK: - Helpers

private func nextTick() async {
  _ = await withCheckedContinuation { continuation in
    Task {
      await MainActor.run {
        continuation.resume(returning: ())
      }
    }
  }
}

extension DependencyValues {
  fileprivate mutating func setDefaulfMockValues() {
    llmService = MockLLMService()
    settingsService = MockSettingsService()
  }
}
