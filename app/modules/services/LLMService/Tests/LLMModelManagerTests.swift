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

// MARK: - AIModelsManagerTests

@Suite("AIModelsManager Tests")
class AIModelsManagerTests {

  // MARK: - Initialization Tests

  @Test("Initializes with models loaded from file")
  func test_init_loadsModelsFromFile() throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)],
      openAI: [makeTestModel(providerId: "gpt-5", slug: "gpt-latest", provider: .openAI)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService()

    // when
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // then
    #expect(sut.modelsAvailable(for: .anthropic).currentValue.count == 1)
    #expect(sut.modelsAvailable(for: .openAI).currentValue.count == 1)
    #expect(sut.getModel(by: "claude-sonnet").currentValue?.modelInfo.slug == "claude-sonnet-4")
    #expect(sut.getModel(by: "gpt-5").currentValue?.modelInfo.slug == "gpt-latest")
  }

  @Test("Initializes with empty models when file does not exist")
  func test_init_withNoFile() throws {
    // given
    let fileManager = MockFileManager()
    let settingsService = MockSettingsService()

    // when
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // then
    #expect(sut.modelsAvailable(for: .anthropic).currentValue.isEmpty)
    #expect(sut.modelsAvailable(for: .openAI).currentValue.isEmpty)
  }

  @Test("Initializes with empty models when file has invalid data")
  func test_init_withInvalidFileData() throws {
    // given
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": "invalid json",
    ])
    let settingsService = MockSettingsService()

    // when
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // then
    #expect(sut.modelsAvailable(for: .anthropic).currentValue.isEmpty)
    #expect(sut.modelsAvailable(for: .openAI).currentValue.isEmpty)
  }

  // MARK: - Model Retrieval Tests

  @Test("modelsAvailable returns models for specific provider")
  func test_modelsAvailable_returnsModelsForProvider() throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [
        makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic),
        makeTestModel(providerId: "claude-haiku", slug: "claude-haiku-35", provider: .anthropic),
      ],
      openAI: [makeTestModel(providerId: "gpt-5", slug: "gpt-latest", provider: .openAI)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let anthropicModels = sut.modelsAvailable(for: .anthropic).currentValue
    let openAIModels = sut.modelsAvailable(for: .openAI).currentValue

    // then
    #expect(anthropicModels.count == 2)
    #expect(openAIModels.count == 1)
    #expect(anthropicModels.map(\.id).sorted() == ["claude-haiku", "claude-sonnet"])
  }

  @Test("modelsAvailable returns empty array for provider with no models")
  func test_modelsAvailable_returnsEmptyForUnknownProvider() throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let groqModels = sut.modelsAvailable(for: .groq).currentValue

    // then
    #expect(groqModels.isEmpty)
  }

  @Test("getModel returns correct model by provider ID")
  func test_getModel_returnsModelByProviderId() throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [
        makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic),
        makeTestModel(providerId: "claude-haiku", slug: "claude-haiku-35", provider: .anthropic),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let model = sut.getModel(by: "claude-sonnet").currentValue

    // then
    #expect(model?.id == "claude-sonnet")
    #expect(model?.modelInfo.slug == "claude-sonnet-4")
    #expect(model?.provider == .anthropic)
  }

  @Test("getModel returns nil for non-existent provider ID")
  func test_getModel_returnsNilForNonExistentId() throws {
    // given
    let fileManager = MockFileManager()
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let model = sut.getModel(by: "non-existent-id").currentValue

    // then
    #expect(model == nil)
  }

  @Test("getModelInfo returns correct model info by slug")
  func test_getModelInfo_returnsModelInfoBySlug() throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let modelInfo = sut.getModelInfo(by: "claude-sonnet-4").currentValue

    // then
    #expect(modelInfo?.slug == "claude-sonnet-4")
    #expect(modelInfo?.name == "Test Model")
  }

  @Test("getModelInfo returns nil for non-existent slug")
  func test_getModelInfo_returnsNilForNonExistentSlug() throws {
    // given
    let fileManager = MockFileManager()
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let modelInfo = sut.getModelInfo(by: "non-existent-slug").currentValue

    // then
    #expect(modelInfo == nil)
  }

  @Test("provider returns preferred provider when set")
  func test_provider_returnsPreferedProvider() throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [makeTestModel(providerId: "anthropic/claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)],
      openRouter: [makeTestModel(providerId: "openrouter/claude-sonnet", slug: "claude-sonnet-4", provider: .openRouter)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      preferedProviders: ["claude-sonnet-4": .openRouter],
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(apiKey: "old-key", baseUrl: nil, executable: nil, createdOrder: 1),
        .openRouter: Settings.AIProviderSettings(apiKey: "old-key", baseUrl: nil, executable: nil, createdOrder: 2),
      ]))
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())
    let modelInfo = try #require(sut.getModelInfo(by: "claude-sonnet-4").currentValue)

    // when
    let provider = sut.provider(for: modelInfo).currentValue

    // then
    #expect(provider == .openRouter)
  }

  @Test("provider returns preferred provider that are configured")
  func test_provider_returnsPreferedProviderThatAreConfigured() throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [makeTestModel(providerId: "anthropic/claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settings = Settings(
      preferedProviders: ["claude-sonnet-4": .openRouter],
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(apiKey: "old-key", baseUrl: nil, executable: nil, createdOrder: 1),
      ])
    print(settings.preferedProviders)
    let settingsService = MockSettingsService(settings)
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())
    let modelInfo = try #require(sut.getModelInfo(by: "claude-sonnet-4").currentValue)

    // when
    let provider = sut.provider(for: modelInfo).currentValue

    // then
    #expect(provider == .anthropic) // The preferred provider was set to open routed, which is not available anymore.
  }

  @Test("provider returns first available provider when no preference set")
  func test_provider_returnsFirstAvailableProvider() throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [makeTestModel(providerId: "anthropic/claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService()
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())
    let modelInfo = try #require(sut.getModelInfo(by: "claude-sonnet-4").currentValue)

    // when
    let provider = sut.provider(for: modelInfo).currentValue

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
    server.onPostRequest = { path, data, _ in
      #expect(path == "models")
      data.expectToMatch("""
        {
          "provider" : {
            "name" : "anthropic",
            "settings" : {
              "apiKey" : "test-key"
            }
          }
        }
        """)
      return try JSONEncoder().encode(serverModelsResponse)
    }
    let fileManager = MockFileManager()
    let settingsService = MockSettingsService()
    let sut = AIModelsManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let models = try await sut.refetchModelsAvailable(
      for: .anthropic,
      newSettings: Settings.AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1))

    // then
    #expect(models.count == 2)
    #expect(models.map(\.id).sorted() == ["claude-haiku-new", "claude-sonnet-new"])
    #expect(sut.modelsAvailable(for: .anthropic).currentValue.count == 2)
  }

  @Test("refetchModelsAvailable replaces old models for provider")
  func test_refetchModelsAvailable_replacesOldModels() async throws {
    // given
    let oldModelsData = makePersistedProviderModelsJSON(
      anthropic: [makeTestModel(providerId: "old-model", slug: "old-slug", provider: .anthropic)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": oldModelsData,
    ])

    let serverModelsResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "new-model", globalId: "new-slug", name: "New Model"),
    ])
    let server = MockLocalServer()
    server.onPostRequest = { _, data, _ in
      data.expectToMatch("""
        {
          "provider" : {
            "name" : "anthropic",
            "settings" : {
              "apiKey" : "test-key"
            }
          }
        }
        """)
      return try JSONEncoder().encode(serverModelsResponse)
    }

    let sut = AIModelsManager(
      localServer: server,
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    _ = try await sut.refetchModelsAvailable(
      for: .anthropic,
      newSettings: Settings.AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1))

    // then
    let anthropicModels = sut.modelsAvailable(for: .anthropic).currentValue
    #expect(anthropicModels.count == 1)
    #expect(anthropicModels.first?.id == "new-model")
    #expect(sut.getModel(by: "old-model").currentValue == nil)
  }

  @Test("refetchModelsAvailable persists models to file")
  func test_refetchModelsAvailable_persistsToFile() async throws {
    // given
    let serverModelsResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "claude-sonnet", globalId: "claude-sonnet-4", name: "Claude Sonnet"),
    ])
    let server = MockLocalServer()
    server.onPostRequest = { _, data, _ in
      data.expectToMatch("""
        {
          "provider" : {
            "name" : "anthropic",
            "settings" : {
              "apiKey" : "test-key"
            }
          }
        }
        """)
      return try JSONEncoder().encode(serverModelsResponse)
    }
    let fileManager = MockFileManager()
    let sut = AIModelsManager(
      localServer: server,
      settingsService: MockSettingsService(),
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    _ = try await sut.refetchModelsAvailable(
      for: .anthropic,
      newSettings: Settings.AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1))

    // then
    let persistedPath = URL(fileURLWithPath: "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json")
    let persistedData = try #require(fileManager.files[persistedPath])
    let decoded = try JSONDecoder().decode(PersistedAIProviderModels.self, from: persistedData)
    #expect(decoded.models[.anthropic]?.count == 1)
    #expect(decoded.models[.anthropic]?.first?.providerId == "claude-sonnet")
  }

  // MARK: - Active Models Tests

  @Test("activeModels filters by enabled models")
  func test_activeModels_filtersByEnabledModels() async throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [
        makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic),
        makeTestModel(providerId: "claude-haiku", slug: "claude-haiku-35", provider: .anthropic),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      enabledModels: ["claude-sonnet-4"]))
    let sut = AIModelsManager(
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
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [
        makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic),
        makeTestModel(providerId: "claude-haiku", slug: "claude-haiku-35", provider: .anthropic),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      enabledModels: ["claude-sonnet-4"]))
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    let receivedUpdates = expectation(description: "Received activeModels update")
    let updateCount = Atomic(0)

    sut.activeModels.sink { models in
      let count = updateCount.increment()
      if count == 2 { // First update is initial value, second is after our change
        #expect(models.count == 2)
        #expect(models.map(\.slug).sorted() == ["claude-haiku-35", "claude-sonnet-4"])
        receivedUpdates.fulfill()
      }
    }.store(in: &cancellables)

    // when
    settingsService.update(setting: \.enabledModels, to: ["claude-sonnet-4", "claude-haiku-35"])

    // then
    try await fulfillment(of: [receivedUpdates])
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
    server.onPostRequest = { _, data, _ in
      data.expectToMatch("""
        {
          "provider" : {
            "name" : "anthropic",
            "settings" : {
              "apiKey" : "test-key"
            }
          }
        }
        """)
      requestReceived.fulfill()
      return try JSONEncoder().encode(serverModelsResponse)
    }
    let settingsService = MockSettingsService(Settings(llmProviderSettings: [:]))
    let fileManager = MockFileManager()
    let sut = AIModelsManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    let modelsUpdated = expectation(description: "Models updated")
    sut.models.sink { models in
      if !models.isEmpty {
        modelsUpdated.fulfillAtMostOnce()
      }
    }.store(in: &cancellables)

    // when
    settingsService.update(
      setting: \.llmProviderSettings,
      to: [.anthropic: Settings.AIProviderSettings(apiKey: "test-key", baseUrl: nil, executable: nil, createdOrder: 1)])

    // then
    try await fulfillment(of: [requestReceived, modelsUpdated])
    #expect(sut.modelsAvailable(for: .anthropic).currentValue.count == 1)
  }

  @Test("Automatically fetches models when provider settings are updated")
  func test_observeSettings_fetchesModelsWhenProviderUpdated() async throws {
    // given
    let requestCount = Atomic(0)
    let serverModelsResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "claude-sonnet", globalId: "claude-sonnet-4", name: "Claude Sonnet"),
    ])
    let server = MockLocalServer()
    let firstRequestReceived = expectation(description: "First server request received")
    let secondRequestReceived = expectation(description: "Second server request received")
    server.onPostRequest = { _, data, _ in
      let count = requestCount.increment()
      if count == 1 {
        data.expectToMatch("""
          {
            "provider" : {
              "name" : "anthropic",
              "settings" : {
                "apiKey" : "old-key"
              }
            }
          }
          """)
        firstRequestReceived.fulfill()
      } else if count == 2 {
        data.expectToMatch("""
          {
            "provider" : {
              "name" : "anthropic",
              "settings" : {
                "apiKey" : "new-key"
              }
            }
          }
          """)
        secondRequestReceived.fulfill()
      }
      return try JSONEncoder().encode(serverModelsResponse)
    }
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(apiKey: "old-key", baseUrl: nil, executable: nil, createdOrder: 1),
      ]))
    let fileManager = MockFileManager()
    let sut = AIModelsManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    try await fulfillment(of: [firstRequestReceived])

    // when
    settingsService.update(
      setting: \.llmProviderSettings,
      to: [.anthropic: Settings.AIProviderSettings(apiKey: "new-key", baseUrl: nil, executable: nil, createdOrder: 1)])

    // then
    try await fulfillment(of: [secondRequestReceived], timeout: 2)
    #expect(requestCount.value == 2)
    _ = sut
  }

  @Test("Removes models when provider is removed from settings")
  func test_observeSettings_removesModelsWhenProviderRemoved() async throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [makeTestModel(providerId: "claude-sonnet", slug: "claude-sonnet-4", provider: .anthropic)],
      openAI: [makeTestModel(providerId: "gpt-5", slug: "gpt-latest", provider: .openAI)])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(apiKey: "key1", baseUrl: nil, executable: nil, createdOrder: 1),
        .openAI: Settings.AIProviderSettings(apiKey: "key2", baseUrl: nil, executable: nil, createdOrder: 2),
      ]))
    let sut = AIModelsManager(
      localServer: MockLocalServer(),
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    let modelsUpdated = expectation(description: "Models updated after provider removal")
    sut.models.sink { models in
      if !models.contains(where: { $0.slug == "claude-sonnet-4" }) {
        modelsUpdated.fulfillAtMostOnce()
      }
    }.store(in: &cancellables)

    // when
    settingsService.update(
      setting: \.llmProviderSettings,
      to: [.openAI: Settings.AIProviderSettings(apiKey: "key2", baseUrl: nil, executable: nil, createdOrder: 2)])

    // then
    try await fulfillment(of: [modelsUpdated])
    #expect(sut.modelsAvailable(for: .anthropic).currentValue.isEmpty)
    #expect(sut.modelsAvailable(for: .openAI).currentValue.count == 1)
    #expect(sut.getModel(by: "claude-sonnet").currentValue == nil)
    #expect(sut.getModel(by: "gpt-5").currentValue != nil)
  }

  // MARK: - External Agent Tests

  @Test("External agent models are created with special properties")
  func test_externalAgent_createsModelWithSpecialProperties() async throws {
    // given
    let server = MockLocalServer()
    server.onPostRequest = { _, _, _ in
      // Should not be called for external agents
      Issue.record("Should not fetch models from server for external agents")
      return Data()
    }
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .claudeCode: Settings.AIProviderSettings(apiKey: "", baseUrl: nil, executable: "/path/to/claude", createdOrder: 1),
      ]))
    let fileManager = MockFileManager()
    let sut = AIModelsManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    // when
    let models = try await sut.refetchModelsAvailable(
      for: .claudeCode,
      newSettings: Settings.AIProviderSettings(apiKey: "", baseUrl: nil, executable: "/path/to/claude", createdOrder: 1))

    // then
    #expect(models.count == 1)
    let model = try #require(models.first)
    #expect(model.providerId == "claudeCode")
    #expect(model.provider == .claudeCode)
    #expect(model.modelInfo.name == "Claude Code")
    #expect(model.modelInfo.slug == "claudeCode")
    #expect(model.modelInfo.contextSize == .max)
    #expect(model.modelInfo.maxOutputTokens == .max)
    #expect(model.modelInfo.defaultPricing == nil)
  }

  @Test("External agent models are always active regardless of enabledModels")
  func test_externalAgent_alwaysActiveRegardlessOfEnabledModels() async throws {
    // given
    let anthropicResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "claude-sonnet", globalId: "claude-sonnet-4", name: "Claude Sonnet"),
    ])
    let server = MockLocalServer()
    server.onPostRequest = { _, data, _ in
      data.expectToMatch("""
        {
          "provider" : {
            "name" : "anthropic",
            "settings" : {
              "apiKey" : "key1"
            }
          }
        }
        """)
      return try JSONEncoder().encode(anthropicResponse)
    }
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(apiKey: "key1", baseUrl: nil, executable: nil, createdOrder: 1),
        .claudeCode: Settings.AIProviderSettings(apiKey: "", baseUrl: nil, executable: "/path/to/claude", createdOrder: 2),
      ],
      enabledModels: ["claude-sonnet-4"])) // Only enable claude-sonnet, NOT claudeCode
    let fileManager = MockFileManager()
    let sut = AIModelsManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    let modelsReady = expectation(description: "Both models are active")
    sut.models.sink { models in
      if
        models.count == 2,
        models.contains(where: { $0.slug == "claude-sonnet-4" }),
        models.contains(where: { $0.slug == "claudeCode" })
      {
        modelsReady.fulfillAtMostOnce()
      }
    }.store(in: &cancellables)

    // then
    try await fulfillment(of: [modelsReady])
    let activeModels = sut.activeModels.currentValue
    #expect(activeModels.count == 2) // Both claude-sonnet AND claudeCode
    #expect(activeModels.contains(where: { $0.slug == "claude-sonnet-4" }))
    #expect(activeModels.contains(where: { $0.slug == "claudeCode" })) // Even though not in enabledModels
  }

  @Test("External agent models remain active when enabledModels changes")
  func test_externalAgent_remainsActiveWhenEnabledModelsChange() async throws {
    // given
    let anthropicResponse = makeListModelsOutput(models: [
      makeSchemaModel(providerId: "claude-sonnet", globalId: "claude-sonnet-4", name: "Claude Sonnet"),
    ])
    let server = MockLocalServer()
    server.onPostRequest = { _, data, _ in
      data.expectToMatch("""
        {
          "provider" : {
            "name" : "anthropic",
            "settings" : {
              "apiKey" : "key1"
            }
          }
        }
        """)
      return try JSONEncoder().encode(anthropicResponse)
    }
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(apiKey: "key1", baseUrl: nil, executable: nil, createdOrder: 1),
        .claudeCode: Settings.AIProviderSettings(apiKey: "", baseUrl: nil, executable: "/path/to/claude", createdOrder: 2),
      ],
      enabledModels: ["claude-sonnet-4"]))
    let fileManager = MockFileManager()
    let sut = AIModelsManager(
      localServer: server,
      settingsService: settingsService,
      fileManager: fileManager,
      shellService: MockShellService())

    let initialModelsReady = expectation(description: "Initial models are ready")
    sut.models.sink { models in
      if models.count == 2 {
        initialModelsReady.fulfillAtMostOnce()
      }
    }.store(in: &cancellables)
    try await fulfillment(of: [initialModelsReady])

    let receivedUpdates = expectation(description: "Received activeModels update")
    let updateCount = Atomic(0)

    sut.activeModels.sink { models in
      let count = updateCount.increment()
      if count == 2 { // First update is initial value, second is after our change
        // Even when enabledModels is empty, claudeCode should still be active
        #expect(models.count == 1)
        #expect(models.first?.slug == "claudeCode")
        receivedUpdates.fulfill()
      }
    }.store(in: &cancellables)

    // when
    settingsService.update(setting: \.enabledModels, to: []) // Clear all enabled models

    // then
    try await fulfillment(of: [receivedUpdates])
  }

  // MARK: - Low Tier Model Tests

  @Test("lowTierModel returns cheapest model from configured providers")
  func test_lowTierModel_returnsCheapestModel() async throws {
    // given
    let anthropicLowTier = try #require(AIProvider.anthropic.lowTierModelId)
    let openAILowTier = try #require(AIProvider.openAI.lowTierModelId)
    let modelsData = makePersistedProviderModelsJSON(
      anthropic: [
        makeTestModel(
          providerId: "claude-3.5-haiku",
          slug: anthropicLowTier,
          provider: .anthropic,
          pricing: ModelPricing(input: 0.8, output: 4, cacheWrite: 0.2, cachedInput: 0.08)),
      ],
      openAI: [
        makeTestModel(
          providerId: "gpt-3.5-turbo",
          slug: openAILowTier,
          provider: .openAI,
          pricing: ModelPricing(input: 0.25, output: 2, cacheWrite: 0.0625, cachedInput: 0.025)),
      ])
    let fileManager = MockFileManager(files: [
      "/mock/applicationSupport/\(Bundle.main.hostAppBundleId)/llmProviders.json": modelsData,
    ])
    let settingsService = MockSettingsService(Settings(
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(apiKey: "key1", baseUrl: nil, executable: nil, createdOrder: 1),
        .openAI: Settings.AIProviderSettings(apiKey: "key2", baseUrl: nil, executable: nil, createdOrder: 2),
      ],
      enabledModels: [anthropicLowTier, openAILowTier]))
    let llmModelManager = AIModelsManager(
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
    #expect(lowTierModel?.modelInfo.slug == openAILowTier)
    #expect(lowTierModel?.provider == .openAI)
  }

  @Test("lowTierModel returns nil when no low tier models are enabled")
  func test_lowTierModel_returnsNilWhenNoneEnabled() async throws {
    // given
    let modelsData = makePersistedProviderModelsJSON(
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
        .anthropic: Settings.AIProviderSettings(apiKey: "key1", baseUrl: nil, executable: nil, createdOrder: 1),
      ],
      enabledModels: [])) // No models enabled
    let llmModelManager = AIModelsManager(
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
    let llmModelManager = AIModelsManager(
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

  private var cancellables = Set<AnyCancellable>()

}

// MARK: - Test Helpers

private func makeTestModel(
  providerId: String,
  slug: String,
  provider: AIProvider,
  pricing: ModelPricing? = nil)
  -> AIProviderModel
{
  AIProviderModel(
    providerId: providerId,
    provider: provider,
    modelInfo: AIModel(
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

private func makePersistedProviderModelsJSON(
  anthropic: [AIProviderModel] = [],
  openAI: [AIProviderModel] = [],
  openRouter: [AIProviderModel] = [])
  -> String
{
  var dict = [AIProvider: [AIProviderModel]]()
  if !anthropic.isEmpty { dict[.anthropic] = anthropic }
  if !openAI.isEmpty { dict[.openAI] = openAI }
  if !openRouter.isEmpty { dict[.openRouter] = openRouter }

  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let data = try! encoder.encode(PersistedAIProviderModels(models: dict))
  return String(data: data, encoding: .utf8)!
}
