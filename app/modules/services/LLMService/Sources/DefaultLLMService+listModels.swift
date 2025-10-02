// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import LLMFoundation
import LocalServerServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe

// MARK: - LLMModelManager

@ThreadSafe
final class LLMModelManager: Sendable {

  init(
    localServer: LocalServer,
    settingsService: SettingsService,
    fileManager: FileManagerI,
    shellService: ShellService)
  {
    self.localServer = localServer
    self.settingsService = settingsService
    self.fileManager = fileManager
    self.shellService = shellService

    let llmModelByProvider = (try? Self.loadModels(fileManager: fileManager)) ?? [:]
    self.llmModelByProvider = llmModelByProvider
    modelsById = llmModelByProvider.values.flatMap(\.self).reduce(into: [:]) { acc, model in
      acc[model.id] = model
    }
    modelByModelSlug = llmModelByProvider.values.flatMap(\.self).reduce(into: [:]) { acc, model in
      acc[model.modelInfo.id, default: []].append(model)
    }
    modelInfosByModelSlug = llmModelByProvider.values.flatMap(\.self).reduce(into: [:]) { acc, model in
      acc[model.modelInfo.id] = model.modelInfo
    }
    observerChangesToSettings()
  }

  var models: ReadonlyCurrentValueSubject<[LLMModelInfo], Never> {
    mutableModels.readonly()
  }

  var activeModels: ReadonlyCurrentValueSubject<[LLMModelInfo], Never> {
    ReadonlyCurrentValueSubject<[LLMModelInfo], Never>(
      models.currentValue.filter { settingsService.value(for: \.enabledModels).contains($0.id) },
      publisher: models.map { @Sendable [weak self] models in
        guard let self else { return [] }
        return models.filter { self.settingsService.value(for: \.enabledModels).contains($0.id) }
      }
      .removeDuplicates()
      .eraseToAnyPublisher())
  }

  func listModelAvailable(for provider: LLMProvider) -> [LLMModel] {
    llmModelByProvider[provider] ?? []
  }

  func refetchModelsAvailable(for provider: LLMProvider, newSettings: Settings.LLMProviderSettings) async throws -> [LLMModel] {
    try await fetchModelAvailable(for: provider, settings: newSettings)
  }

  func getModel(by modelId: String) -> LLMModel? {
    modelsById[modelId]
  }

  func getModelInfo(by modelInfoId: String) -> LLMModelInfo? {
    modelInfosByModelSlug[modelInfoId]
  }

  func provider(for model: LLMModelInfo) -> LLMProvider? {
    settingsService.value(for: \.preferedProviders)[model.id] ?? modelByModelSlug[model.id]?.first?.provider
  }

  private let localServer: LocalServer
  private let settingsService: SettingsService
  private let fileManager: FileManagerI
  private let shellService: ShellService

  private var llmModelByProvider: [LLMProvider: [LLMModel]]
  private var modelsById: [String: LLMModel]
  private var modelByModelSlug: [String: [LLMModel]]
  private var modelInfosByModelSlug: [String: LLMModelInfo]
  private var cancellables = Set<AnyCancellable>()

  private let mutableModels = CurrentValueSubject<[LLMModelInfo], Never>([])

  private let queue = TaskQueue<Void, Never>()

  private static func loadModels(fileManager: FileManagerI) throws -> [LLMProvider: [LLMModel]] {
    let cacheURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.hostAppBundleId)
      .appendingPathComponent("llmProviders.json")
    let decoder = JSONDecoder()

    let data = try fileManager.read(dataFrom: cacheURL)
    return try decoder.decode(PersistedLLMModels.self, from: data).models
  }

  private static func persist(models: [LLMProvider: [LLMModel]], fileManager: FileManagerI) throws {
    let cacheURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.hostAppBundleId)
      .appendingPathComponent("llmProviders.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let data = try encoder.encode(PersistedLLMModels(models: models))
    try fileManager.write(data: data, to: cacheURL)
  }

  private static func remove(provider: LLMProvider, from state: inout _InternalState) {
    let udpatedModelIds = state.llmModelByProvider.removeValue(forKey: provider)?.map(\.id) ?? []
    for modelId in udpatedModelIds {
      guard let modelInfo = state.modelsById.removeValue(forKey: modelId)?.modelInfo else { continue }
      state.modelByModelSlug[modelInfo.id]?.removeAll(where: { $0.id == modelId })
      if state.modelByModelSlug[modelInfo.id]?.isEmpty == true {
        state.modelByModelSlug.removeValue(forKey: modelInfo.id)
        state.modelInfosByModelSlug.removeValue(forKey: modelInfo.id)
      }
    }
  }

  private static func add(models: [LLMModel], for provider: LLMProvider, to state: inout _InternalState) {
    state.llmModelByProvider[provider] = models
    for model in models {
      state.modelsById[model.id] = model
      state.modelByModelSlug[model.modelInfo.id, default: []].append(model)
      state.modelInfosByModelSlug[model.modelInfo.id] = model.modelInfo
    }
  }

  private func fetchModelAvailable(for provider: LLMProvider, settings: LLMProviderSettings) async throws -> [LLMModel] {
    let apiProvider = try await Schema.APIProvider(
      provider: provider,
      settings: settings,
      shellService: shellService,
      projectRoot: nil)

    let data = try JSONEncoder().encode(Schema.ListModelsInput(provider: .init(
      name: apiProvider.name,
      settings: apiProvider.settings)))
    let response: Schema.ListModelsOutput = try await localServer.postRequest(path: "models", data: data)
    let models = response.models.map { LLMModel(
      providerId: $0.providerId,
      provider: provider,
      modelInfo: .init(
        name: $0.name,
        slug: $0.globalId,
        contextSize: $0.contextLength,
        maxOutputTokens: $0.maxCompletionTokens,
        defaultPricing: .init(
          input: $0.pricing.prompt,
          output: $0.pricing.completion,
          cacheWrite: $0.pricing.inputCacheWrite ?? 0,
          cachedInput: $0.pricing.inputCacheRead ?? 0),
        createdAt: $0.createdAt,
        rankForProgramming: $0.rankForProgramming)) }

    let llmModelByProvider = inLock { state in
      // First remove old models to avoid keeping stale data.
      Self.remove(provider: provider, from: &state)
      // Then add new models.
      Self.add(models: models, for: provider, to: &state)
      return state.llmModelByProvider
    }

    do {
      try Self.persist(models: llmModelByProvider, fileManager: fileManager)
    } catch {
      defaultLogger.error("Failed to persist models", error)
    }

    let modelInfos: [LLMModelInfo] = inLock { state in
      Self.remove(provider: provider, from: &state)
      Self.add(models: models, for: provider, to: &state)
      return state.modelInfosByModelSlug.values.sorted(by: { $0.name < $1.name })
    } ?? []
    mutableModels.send(modelInfos)

    return models
  }

  private func observerChangesToSettings() {
    let previousSettings = Atomic<[LLMProvider: LLMProviderSettings]?>(nil)
    settingsService.liveValue(for: \.llmProviderSettings).sink { @Sendable [weak self] llmProviderSettings in
      let previous = previousSettings.set(to: llmProviderSettings)
      Task {
        await self?.updateModels(from: previous, to: llmProviderSettings)
      }
    }.store(in: &cancellables)
    settingsService.liveValue(for: \.enabledModels).sink { @Sendable [weak self] _ in
      guard let self else { return }
      mutableModels.send(mutableModels.value) // This will trigger a new filtering of active models
    }.store(in: &cancellables)
  }

  private func updateModels(
    from previous: [LLMProvider: LLMProviderSettings]?,
    to current: [LLMProvider: LLMProviderSettings]?)
    async
  {
    @Sendable
    func _updateModels(
      from previous: [LLMProvider: LLMProviderSettings]?,
      to current: [LLMProvider: LLMProviderSettings]?)
      async
    {
      // Remove providers that are no longer present
      let removedProviders = (previous ?? [:]).keys.filter { current?[$0] == nil }
      let modelInfos = inLock { state in
        for provider in removedProviders {
          Self.remove(provider: provider, from: &state)
        }
        return state.modelInfosByModelSlug.values.sorted(by: { $0.name < $1.name })
      }
      mutableModels.send(modelInfos)

      // Fetch models for updated providers.
      let updatedProviders = (current ?? [:]).filter { previous?[$0.key] != $0.value }

      await withTaskGroup { group in
        for (provider, providerSettings) in updatedProviders {
          group.addTask { @Sendable in
            do {
              _ = try await self.fetchModelAvailable(for: provider, settings: providerSettings)
            } catch {
              defaultLogger.error("Failed to fetch models for provider \(provider.id)", error)
            }
          }
        }
        await group.waitForAll()
      }

      do {
        try Self.persist(models: llmModelByProvider, fileManager: fileManager)
      } catch {
        defaultLogger.error("Failed to persist models", error)
      }
    }
    // Ensure that those updates are serial, since they rely on the change between two states.
    await queue.queue {
      await _updateModels(from: previous, to: current)
    }.value
  }

}

extension DefaultLLMService {

  var activeModels: ReadonlyCurrentValueSubject<[LLMModelInfo], Never> {
    llmModelsManager.activeModels
  }

  func modelsAvailable(for provider: LLMProvider) -> [LLMModel] {
    llmModelsManager.listModelAvailable(for: provider)
  }

  func refetchModelsAvailable(for provider: LLMProvider, newSettings: Settings.LLMProviderSettings) async throws -> [LLMModel] {
    try await llmModelsManager.refetchModelsAvailable(for: provider, newSettings: newSettings)
  }

  func getModel(by modelId: String) -> LLMModel? {
    llmModelsManager.getModel(by: modelId)
  }

  func getModelInfo(by modelInfoId: String) -> LLMModelInfo? {
    llmModelsManager.getModelInfo(by: modelInfoId)
  }

  func provider(for model: LLMModelInfo) -> LLMProvider? {
    llmModelsManager.provider(for: model)
  }
}

// MARK: - PersistedLLMModels

private struct PersistedLLMModels: Codable {
  init(models: [LLMProvider: [LLMModel]]) {
    self.models = models
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let keys = container.allKeys
    var dict = [LLMProvider: [LLMModel]]()
    for key in keys {
      let models = try container.decode([LLMModel].self, forKey: key)
      if let provider = LLMProvider(rawValue: key) {
        dict[provider] = models
      }
    }
    models = dict
  }

  let models: [LLMProvider: [LLMModel]]

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    for (provider, models) in models {
      try container.encode(models, forKey: provider.id)
    }
  }

}
