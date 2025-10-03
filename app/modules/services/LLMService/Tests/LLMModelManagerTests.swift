// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LLMFoundation
import LocalServerServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import SwiftTesting
import Testing
import ThreadSafe
@testable import LLMService

// MARK: - LLMModelManagerTests

@Suite("LLMModelManager Tests")
struct LLMModelManagerTests {

  // MARK: - Initialization Tests

  @Test("Initializes with models loaded from file")
  func test_init_loadsModelsFromFile() throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)],
      openAI: [makeTestModel(providerId: "gpt-5", slug: "gpt-latest", provider: .openAI)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService()

    // when
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // then
    #expect(sut.modelsAvailable(for: .anthropic).count == 1)
    #expect(sut.modelsAvailable(for: .openAI).count == 1)
    #expect(sut.getModel(by: "claude-sonnet")?.modelInfo.slug == "claude-sonnet-4")
    #expect(sut.getModel(by: "gpt-5")?.modelInfo.slug == "gpt-latest")
  }

  @Test("Initializes with empty models when file does not exist")
  func test_init_withNoFile() throws {
    // given
    let fileManager = MockFileManager()
    let settingsService = MockSettingsService()

    // when
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // then
    #expect(sut.modelsAvailable(for: .anthropic).isEmpty)
    #expect(sut.modelsAvailable(for: .openAI).isEmpty)
  }

  @Test("Initializes with empty models when file has invalid data")
  func test_init_withInvalidFileData() throws {
    // given
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": "invalid json",
    ])
    let settingsService = MockSettingsService()

    // when
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // then
    #expect(sut.modelsAvailable(for: .anthropic).isEmpty)
    #expect(sut.modelsAvailable(for: .openAI).isEmpty)
  }

  // MARK: - Model Retrieval Tests

  @Test("modelsAvailable returns models for specific provider")
  func test_modelsAvailable_returnsModelsForProvider() throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [
        makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic),
        makeTestModel(providerId: "claude-haiku", slug: "claude-haiku-35", provider: .anthropic),
      ],
      openAI: [makeTestModel(providerId: "gpt-5", slug: "gpt-latest", provider: .openAI)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let anthropicModels = sut.modelsAvailable(for: .anthropic)
    let openAIModels = sut.modelsAvailable(for: .openAI)

    // then
    #expect(anthropicModels.count == 2)
    #expect(openAIModels.count == 1)
    #expect(anthropicModels.map(\.id).sorted() == ["claude-haiku", "claude-sonnet"])
  }

  @Test("modelsAvailable returns empty array for provider with no models")
  func test_modelsAvailable_returnsEmptyForUnknownProvider() throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let groqModels = sut.modelsAvailable(for: .groq)

    // then
    #expect(groqModels.isEmpty)
  }

  @Test("getModel returns correct model by provider ID")
  func test_getModel_returnsModelByProviderId() throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [
        makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic),
        makeTestModel(providerId: "claude-haiku", slug: "claude-haiku-35", provider: .anthropic),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let model = sut.getModel(by: "claude-sonnet")

    // then
    #expect(model?.id == "claude-sonnet")
    #expect(model?.modelInfo.slug == "claude-sonnet-4")
    #expect(model?.provider == .anthropic)
  }

  @Test("getModel returns nil for non-existent provider ID")
  func test_getModel_returnsNilForNonExistentId() throws {
    // given
    let fileManager = MockFileManager()
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let model = sut.getModel(by: "non-existent-id")

    // then
    #expect(model == nil)
  }

  @Test("getModelInfo returns correct model info by slug")
  func test_getModelInfo_returnsModelInfoBySlug() throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let modelInfo = sut.getModelInfo(by: "claude-sonnet-4")

    // then
    #expect(modelInfo?.slug == "claude-sonnet-4")
    #expect(modelInfo?.name == "Test Model")
  }

  @Test("getModelInfo returns nil for non-existent slug")
  func test_getModelInfo_returnsNilForNonExistentSlug() throws {
    // given
    let fileManager = MockFileManager()
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let modelInfo = sut.getModelInfo(by: "non-existent-slug")

    // then
    #expect(modelInfo == nil)
  }

  @Test("provider returns preferred provider when set")
  func test_provider_returnsPreferedProvider() throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [makeTestModel(providerId: "anthropic/claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)],
      openRouter: [makeTestModel(providerId: "openrouter/claude-sonnet", slug: "claude-sonnet-4", provider: .openRouter)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      preferedProviders: ["claude-sonnet-4": .openRouter]))
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())
    let modelInfo = try #require(sut.getModelInfo(by: "claude-sonnet-4"))

    // when
    let provider = sut.provider(for: modelInfo)

    // then
    #expect(provider == .openRouter)
  }

  @Test("provider returns first available provider when no preference set")
  func test_provider_returnsFirstAvailableProvider() throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [makeTestModel(providerId: "anthropic/claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService()
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())
    let modelInfo = try #require(sut.getModelInfo(by: "claude-sonnet-4"))

    // when
    let provider = sut.provider(for: modelInfo)

    // then
    #expect(provider == .anthropic)
  }

  // MARK: - Model Refetch Tests

  @Test("refetchModelsAvailable fetches and updates models")
  func test_refetchModelsAvailable_fetchesAndUpdatesModels() async throws {
    // given
    let serverModelsResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "claude-sonnet-new", globalId: "claude-sonnet-4", name: "Claude Sonnet"),
      makeSchemaModel(providerId: "claude-haiku-new", globalId: "claude-haiku-35", name: "Claude Haiku"),
    ])
    let server = MockLocalServer()
    server.onPostRequest = { path, _, _ in
      #expect(path == "models")
      return try JSONEncoder().encode(serverModelsResponse)
    }
    let fileManager = MockFileManager()
    let settingsService = MockSettingsService()
    let sut = LLMModelManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let models = try await sut.refetchModelsAvailable(
      for: .anthropic,
      newSettings: Settings.LLMProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1))

    // then
    #expect(models.count == 2)
    #expect(models.map(\.id).sorted() == ["claude-haiku-new", "claude-sonnet-new"])
    #expect(sut.modelsAvailable(for: .anthropic).count == 2)
  }

  @Test("refetchModelsAvailable replaces old models for provider")
  func test_refetchModelsAvailable_replacesOldModels() async throws {
    // given
    let oldModelsData = makePersistedModelsJSON(
      anthropic: [makeTestModel(providerId: "old-model", slug: "old-slug", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": oldModelsData,
    ])

    let serverModelsResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "new-model", globalId: "new-slug", name: "New Model"),
    ])
    let server = MockLocalServer()
    server.onPostRequest = { _, _, _ in
      try JSONEncoder().encode(serverModelsResponse)
    }

    let sut = LLMModelManager(
      localServer: server,
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    _ = try await sut.refetchModelsAvailable(
      for: .anthropic,
      newSettings: Settings.LLMProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1))

    // then
    let anthropicModels = sut.modelsAvailable(for: .anthropic)
    #expect(anthropicModels.count == 1)
    #expect(anthropicModels.first?.id == "new-model")
    #expect(sut.getModel(by: "old-model") == nil)
  }

  @Test("refetchModelsAvailable persists models to file")
  func test_refetchModelsAvailable_persistsToFile() async throws {
    // given
    let serverModelsResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "claude-sonnet", globalId: "claude-sonnet-4", name: "Claude Sonnet"),
    ])
    let server = MockLocalServer()
    server.onPostRequest = { _, _, _ in
      try JSONEncoder().encode(serverModelsResponse)
    }
    let fileManager = MockFileManager()
    let sut = LLMModelManager(
      localServer: server,
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    _ = try await sut.refetchModelsAvailable(
      for: .anthropic,
      newSettings: Settings.LLMProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1))

    // then
    let persistedPath = URL(fileURLWithPath: "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json")
    let persistedData = try #require(fileManager.files[persistedPath])
    let decoded = try JSONDecoder().decode(PersistedModelsWrapper.self, from: persistedData)
    #expect(decoded.anthropic?.count == 1)
    #expect(decoded.anthropic?.first?.providerId == "claude-sonnet")
  }

  // MARK: - Active Models Tests

  @Test("activeModels filters by enabled models")
  func test_activeModels_filtersByEnabledModels() async throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [
        makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic),
        makeTestModel(providerId: "claude-haiku", slug: "claude-haiku-35", provider: .anthropic),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      enabledModels: ["claude-sonnet-4"]))
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let activeModels = sut.activeModels.currentValue

    // then
    #expect(activeModels.count == 1)
    #expect(activeModels.first?.slug == "claude-sonnet-4")
  }

  @Test("activeModels updates when enabledModels setting changes")
  func test_activeModels_updatesWhenEnabledModelsChange() async throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [
        makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic),
        makeTestModel(providerId: "claude-haiku", slug: "claude-haiku-35", provider: .anthropic),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      enabledModels: ["claude-sonnet-4"]))
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    let receivedUpdates = expectation(description: "Received activeModels update")
    let updateCount = Atomic(0)
    var cancellable: AnyCancellable?

    cancellable = sut.activeModels.sink { models in
      let count = updateCount.increment()
      if count == 2 { // First update is initial value, second is after our change
        #expect(models.count == 2)
        #expect(models.map(\.slug).sorted() == ["claude-haiku-35", "claude-sonnet-4"])
        receivedUpdates.fulfill()
      }
    }

    // when
    settingsService.update(setting: \.enabledModels, to: ["claude-sonnet-4", "claude-haiku-35"])

    // then
    try await fulfillment(of: [receivedUpdates])
    _ = cancellable
  }

  // MARK: - Settings Observation Tests

  @Test("Automatically fetches models when provider is added to settings")
  func test_observeSettings_fetchesModelsWhenProviderAdded() async throws {
    // given
    let serverModelsResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "claude-sonnet", globalId: "claude-sonnet-4", name: "Claude Sonnet"),
    ])
    let server = MockLocalServer()
    let requestReceived = expectation(description: "Server request received")
    server.onPostRequest = { _, _, _ in
      requestReceived.fulfill()
      return try JSONEncoder().encode(serverModelsResponse)
    }
    let settingsService = MockSettingsService(Settings(llmProviderSettings: [:]))
    let fileManager = MockFileManager()
    let sut = LLMModelManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    settingsService.update(
      setting: \.llmProviderSettings,
      to: [.anthropic: Settings.LLMProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1)])

    // then
    try await fulfillment(of: [requestReceived], timeout: 2)
    try await Task.sleep(for: .milliseconds(50))
    #expect(sut.modelsAvailable(for: .anthropic).count == 1)
  }

  @Test("Automatically fetches models when provider settings are updated")
  func test_observeSettings_fetchesModelsWhenProviderUpdated() async throws {
    // given
    let requestCount = Atomic(0)
    let serverModelsResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "claude-sonnet", globalId: "claude-sonnet-4", name: "Claude Sonnet"),
    ])
    let server = MockLocalServer()
    let secondRequestReceived = expectation(description: "Second server request received")
    server.onPostRequest = { _, _, _ in
      if requestCount.increment() == 2 {
        secondRequestReceived.fulfill()
      }
      return try JSONEncoder().encode(serverModelsResponse)
    }
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.LLMProviderSettings(apiKey: "old-key", baseUrl: nil, executable: nil, createdOrder: 1),
      ]))
    let fileManager = MockFileManager()
    let sut = LLMModelManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // Wait for initial fetch
    try await Task.sleep(for: .milliseconds(50))

    // when
    settingsService.update(
      setting: \.llmProviderSettings,
      to: [.anthropic: Settings.LLMProviderSettings(apiKey: "new-key", baseUrl: nil, executable: nil, createdOrder: 1)])

    // then
    try await fulfillment(of: [secondRequestReceived], timeout: 2)
    #expect(requestCount.value == 2)
  }

  @Test("Removes models when provider is removed from settings")
  func test_observeSettings_removesModelsWhenProviderRemoved() async throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)],
      openAI: [makeTestModel(providerId: "gpt-5", slug: "gpt-latest", provider: .openAI)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.LLMProviderSettings(apiKey: "key1", baseUrl: nil, executable: nil, createdOrder: 1),
        .openAI: Settings.LLMProviderSettings(apiKey: "key2", baseUrl: nil, executable: nil, createdOrder: 2),
      ]))
    let sut = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    settingsService.update(
      setting: \.llmProviderSettings,
      to: [.openAI: Settings.LLMProviderSettings(apiKey: "key2", baseUrl: nil, executable: nil, createdOrder: 2)])
    try await Task.sleep(for: .milliseconds(50))

    // then
    #expect(sut.modelsAvailable(for: .anthropic).isEmpty)
    #expect(sut.modelsAvailable(for: .openAI).count == 1)
    #expect(sut.getModel(by: "claude-sonnet") == nil)
    #expect(sut.getModel(by: "gpt-5") != nil)
  }

  // MARK: - Low Tier Model Tests

  @Test("lowTierModel returns cheapest model from configured providers")
  func test_lowTierModel_returnsCheapestModel() async throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [
        makeTestModel(
          providerId: "claude-3.5-haiku",
          slug: "anthropic/claude-3.5-haiku", // Match the lowTierModelId from Anthropic provider
          provider: .anthropic,
          pricing: ModelPricing(input: 0.8, output: 4, cacheWrite: 0.2, cachedInput: 0.08)),
      ],
      openAI: [
        makeTestModel(
          providerId: "gpt-4o-mini",
          slug: "openai/gpt-4o-mini", // Match the lowTierModelId from OpenAI provider
          provider: .openAI,
          pricing: ModelPricing(input: 0.25, output: 2, cacheWrite: 0.0625, cachedInput: 0.025)),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.LLMProviderSettings(apiKey: "key1", baseUrl: nil, executable: nil, createdOrder: 1),
        .openAI: Settings.LLMProviderSettings(apiKey: "key2", baseUrl: nil, executable: nil, createdOrder: 2),
      ],
      enabledModels: ["anthropic/claude-3.5-haiku", "openai/gpt-4o-mini"]))
    let llmModelManager = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())
    let llmService = DefaultLLMService(
      server: MockLocalServer(),
      settingsService: settingsService,
      userDefaults: MockUserDefaults(),
      shellService: MockShellService(),
      fileManager: fileManager,
      llmModelsManager: llmModelManager)

    // when
    let lowTierModel = llmService.lowTierModel()

    // then
    #expect(lowTierModel?.id == "gpt-4o-mini")
    #expect(lowTierModel?.provider == .openAI)
  }

  @Test("lowTierModel returns nil when no low tier models are enabled")
  func test_lowTierModel_returnsNilWhenNoneEnabled() async throws {
    // given
    let modelsData = makePersistedModelsJSON(
      anthropic: [
        makeTestModel(
          providerId: "claude-3.5-haiku",
          slug: "anthropic/claude-3.5-haiku",
          provider: .anthropic,
          pricing: ModelPricing(input: 0.8, output: 4, cacheWrite: 0.2, cachedInput: 0.08)),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.LLMProviderSettings(apiKey: "key1", baseUrl: nil, executable: nil, createdOrder: 1),
      ],
      enabledModels: [])) // No models enabled
    let llmModelManager = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())
    let llmService = DefaultLLMService(
      server: MockLocalServer(),
      settingsService: settingsService,
      userDefaults: MockUserDefaults(),
      shellService: MockShellService(),
      fileManager: fileManager,
      llmModelsManager: llmModelManager)

    // when
    let lowTierModel = llmService.lowTierModel()

    // then
    #expect(lowTierModel == nil)
  }

  @Test("lowTierModel returns nil when no providers configured")
  func test_lowTierModel_returnsNilWhenNoProvidersConfigured() async throws {
    // given
    let fileManager = MockFileManager()
    let settingsService = MockSettingsService(Settings(llmProviderSettings: [:]))
    let llmModelManager = LLMModelManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())
    let llmService = DefaultLLMService(
      server: MockLocalServer(),
      settingsService: settingsService,
      userDefaults: MockUserDefaults(),
      shellService: MockShellService(),
      fileManager: fileManager,
      llmModelsManager: llmModelManager)

    // when
    let lowTierModel = llmService.lowTierModel()

    // then
    #expect(lowTierModel == nil)
  }
}

// MARK: - Test Helpers

private func makeTestModel(
  providerId: String,
  slug: String,
  provider: LLMProvider,
  pricing: ModelPricing? = nil)
  -> LLMModel
{
  LLMModel(
    providerId: providerId,
    provider: provider,
    modelInfo: LLMModelInfo(
      name: "Test Model",
      slug: slug,
      contextSize: 200_000,
      maxOutputTokens: 8_192,
      defaultPricing: pricing ?? ModelPricing(input: 1.0, output: 2.0, cacheWrite: 0.25, cachedInput: 0.1),
      createdAt: Date().timeIntervalSince1970,
      rankForProgramming: 1))
}

private func makeSchemaModel(
  providerId: String,
  globalId: String,
  name: String,
  pricing: Schema.ModelPricing? = nil)
  -> Schema.Model
{
  Schema.Model(
    providerId: providerId,
    globalId: globalId,
    name: name,
    description: "Test description",
    contextLength: 200_000,
    maxCompletionTokens: 8_192,
    inputModalities: [.text],
    outputModalities: [.text],
    pricing: pricing ?? Schema.ModelPricing(
      prompt: 1.0,
      completion: 2.0),
    createdAt: Date().timeIntervalSince1970,
    rankForProgramming: 1)
}

private func makeListModelsOutput(models: [Schema.Model]) -> Schema.ListModelsOutput {
  Schema.ListModelsOutput(models: models)
}

private func makePersistedModelsJSON(
  anthropic: [LLMModel] = [],
  openAI: [LLMModel] = [],
  openRouter: [LLMModel] = [])
  -> String
{
  var dict = [String: [LLMModel]]()
  if !anthropic.isEmpty { dict["anthropic"] = anthropic }
  if !openAI.isEmpty { dict["openai"] = openAI }
  if !openRouter.isEmpty { dict["openrouter"] = openRouter }

  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let data = try! encoder.encode(PersistedModelsWrapper(dict: dict))
  return String(data: data, encoding: .utf8)!
}

// MARK: - PersistedModelsWrapper

/// Helper struct for encoding/decoding persisted models
private struct PersistedModelsWrapper: Codable {
  init(dict: [String: [LLMModel]]) {
    anthropic = dict["anthropic"]
    openai = dict["openai"]
    openrouter = dict["openrouter"]
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let keys = container.allKeys
    for key in keys {
      let models = try container.decode([LLMModel].self, forKey: key)
      if key.caseInsensitiveCompare("anthropic") == .orderedSame {
        anthropic = models
      } else if key.caseInsensitiveCompare("openai") == .orderedSame {
        openai = models
      } else if key.caseInsensitiveCompare("openrouter") == .orderedSame {
        openrouter = models
      }
    }
  }

  var anthropic: [LLMModel]?
  var openai: [LLMModel]?
  var openrouter: [LLMModel]?

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    if let anthropic { try container.encode(anthropic, forKey: "anthropic") }
    if let openai { try container.encode(openai, forKey: "openai") }
    if let openrouter { try container.encode(openrouter, forKey: "openrouter") }
  }
}
