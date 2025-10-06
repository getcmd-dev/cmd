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

// MARK: - AIModelsManagerProtocol

/// Internal protocol used to test different functionalities in DefaultLLMService independently.
protocol AIModelsManagerProtocol: Sendable {
  // Note: Despite being heavy handed, returning an `ReadonlyCurrentValueSubject` for each property has
  // been prefered over alternatives as none satisfied all our requirements of:
  // - Being able to get the current value synchronously
  // - Being able to subscribe to changes
  // - Being read-only
  // - Being thread safe
  // - Not being bound to the main thread
  // - Being performance to scale to 100 of providers that can have 1000 models.
  //
  // Alternatives considered:
  // - `@Published` properties / ObservableObject: Not thread safe if not bound to the main actor.
  // The consumer can easily map an `ReadonlyCurrentValueSubject` to an ObservableObject through `.asObservableObjectBox`
  // - `CurrentValueSubject`: Not read-only
  // - @Observable: Doesn't not cross well protocol boundaries required for DI. Typically bounded to the main actor.
  // The consumer can easily map an `ReadonlyCurrentValueSubject` to an ObservableObject through `.asObservableValue`
  // - Return a higher level object that could be queried for each value of interest.
  // No solution worked well with targetted invalidation when only one model / one provider changes.

  func provider(for model: AIModel) -> ReadonlyCurrentValueSubject<AIProvider?, Never>

  func modelsAvailable(for provider: AIProvider) -> ReadonlyCurrentValueSubject<[AIProviderModel], Never>

  func getModel(by providerModelId: String) -> ReadonlyCurrentValueSubject<AIProviderModel?, Never>

  func getModelInfo(by modelId: AIModelID) -> ReadonlyCurrentValueSubject<AIModel?, Never>

  var availableModels: ReadonlyCurrentValueSubject<[AIModel], Never> { get }

  func refetchModelsAvailable(
    for provider: AIProvider,
    newSettings: Settings.AIProviderSettings)
    async throws -> [AIProviderModel]

  var activeModels: ReadonlyCurrentValueSubject<[AIModel], Never> { get }
}

// MARK: - AIModelsManager

@ThreadSafe
final class AIModelsManager: AIModelsManagerProtocol {
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
    self.llmModelByProvider = .init(llmModelByProvider)
    modelsByProviderId = .init(llmModelByProvider.values.flatMap(\.self).reduce(into: [:]) { acc, model in
      acc[model.id] = model
    })
    providerModelsByModelId = .init(llmModelByProvider.values.flatMap(\.self).reduce(into: [:]) { acc, model in
      acc[model.modelInfo.id, default: []].append(model)
    })
    let modelByModelId = PublishedDictionary<AIModelID, AIModel>(llmModelByProvider.values.flatMap(\.self)
      .reduce(into: [:]) { acc, model in
        acc[model.modelInfo.id] = model.modelInfo
      })
    self.modelByModelId = modelByModelId
    mutableModels = .init(modelByModelId.sortedValues)
    _availableModels = .init(Self.availableModels(
      settings: settingsService.value(for: \.llmProviderSettings),
      models: llmModelByProvider))

    observerChangesToSettings()
  }

  var availableModels: ReadonlyCurrentValueSubject<[AIModel], Never> {
    _availableModels.readonly()
  }

  var models: ReadonlyCurrentValueSubject<[AIModel], Never> {
    mutableModels.readonly()
  }

  var activeModels: ReadonlyCurrentValueSubject<[AIModel], Never> {
    ReadonlyCurrentValueSubject<[AIModel], Never>(
      filterActiveModels(models.currentValue),
      publisher: models.map { @Sendable [weak self] models in
        guard let self else { return [] }
        return filterActiveModels(models)
      }
      .removeDuplicates()
      .eraseToAnyPublisher())
  }

  func provider(for model: AIModel) -> ReadonlyCurrentValueSubject<AIProvider?, Never> {
    let preferredProvider = settingsService.liveValue(for: \.preferedProviders)
    let providersAvailableForModel = providerModelsByModelId.subscribeToValue(for: model.id)

    return ReadonlyCurrentValueSubject<AIProvider?, Never>(
      preferredProvider.currentValue[model.id] ?? providersAvailableForModel.currentValue?.first?.provider,
      publisher: preferredProvider
        .map { $0[model.id] }
        .combineLatest(providersAvailableForModel)
        .map { preferred, providers in
          preferred ?? providers?.first?.provider
        }
        .removeDuplicates()
        .eraseToAnyPublisher())
  }

//  func modelsAvailable(for provider: AIProvider) -> [AIProviderModel] {
//    modelsAvailable(for: provider).currentValue
//  }

  func modelsAvailable(for provider: AIProvider) -> ReadonlyCurrentValueSubject<[AIProviderModel], Never> {
    let publisher = llmModelByProvider.subscribeToValue(for: provider)
    return .init(publisher.currentValue ?? [], publisher: publisher.map { $0 ?? [] }.eraseToAnyPublisher())
  }

  func refetchModelsAvailable(
    for provider: AIProvider,
    newSettings: Settings.AIProviderSettings)
    async throws -> [AIProviderModel]
  {
    try await fetchAndSaveModelsAvailable(for: provider, settings: newSettings)
  }

  func getModel(by providerModelId: String) -> ReadonlyCurrentValueSubject<AIProviderModel?, Never> {
    modelsByProviderId.subscribeToValue(for: providerModelId)
  }

  func getModelInfo(by modelId: AIModelID) -> ReadonlyCurrentValueSubject<AIModel?, Never> {
    modelByModelId.subscribeToValue(for: modelId)
  }

  private let _availableModels: CurrentValueSubject<[AIModel], Never>

  private let localServer: LocalServer
  private let settingsService: SettingsService
  private let fileManager: FileManagerI
  private let shellService: ShellService

  private var llmModelByProvider: PublishedDictionary<AIProvider, [AIProviderModel]>
  private var modelsByProviderId: PublishedDictionary<String, AIProviderModel>
  private var providerModelsByModelId: PublishedDictionary<AIModelID, [AIProviderModel]>
  private var modelByModelId: PublishedDictionary<AIModelID, AIModel>
  private var cancellables = Set<AnyCancellable>()

  private let mutableModels: CurrentValueSubject<[AIModel], Never>

  private let queue = TaskQueue<Void, Never>()

  private static func availableModels(
    settings: [AIProvider: AIProviderSettings],
    models: [AIProvider: [AIProviderModel]])
    -> [AIModel]
  {
    let providers = settings.keys
    let models = providers.compactMap { models[$0] }.flatMap(\.self).reduce(into: [:], { acc, model in
      acc[model.modelInfo.id] = model.modelInfo
    })
    return models.values.sorted(by: { $0.rankForProgramming < $1.rankForProgramming })
  }

  private static func loadModels(fileManager: FileManagerI) throws -> [AIProvider: [AIProviderModel]] {
    let cacheURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.hostAppBundleId)
      .appendingPathComponent("llmProviders.json")
    let decoder = JSONDecoder()

    let data = try fileManager.read(dataFrom: cacheURL)
    return try decoder.decode(PersistedAIProviderModels.self, from: data).models
  }

  private static func persist(models: [AIProvider: [AIProviderModel]], fileManager: FileManagerI) throws {
    let cacheURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.hostAppBundleId)
      .appendingPathComponent("llmProviders.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let data = try encoder.encode(PersistedAIProviderModels(models: models))
    try fileManager.write(data: data, to: cacheURL)
  }

  /// Update the internal state to remove all models for the given provider.
  private static func remove(provider: AIProvider, from state: inout _InternalState) {
    let udpatedModelIds = state.llmModelByProvider.removeValue(forKey: provider)?.map(\.id) ?? []
    for modelId in udpatedModelIds {
      guard let modelInfo = state.modelsByProviderId.removeValue(forKey: modelId)?.modelInfo else { continue }
      state.providerModelsByModelId[modelInfo.id]?.removeAll(where: { $0.id == modelId })
      if state.providerModelsByModelId[modelInfo.id]?.isEmpty == true {
        state.providerModelsByModelId.removeValue(forKey: modelInfo.id)
        state.modelByModelId.removeValue(forKey: modelInfo.id)
      }
    }
  }

  /// Update the internal state to update the models for the given provider, removing pre-existing ones that are not in the new value.
  private static func set(models: [AIProviderModel], for provider: AIProvider, to state: inout _InternalState) {
    var staleProviderModelIds = Set((state.llmModelByProvider[provider] ?? []).map(\.id))
    state.llmModelByProvider[provider] = models
    for model in models {
      state.modelsByProviderId[model.id] = model
      state.providerModelsByModelId[model.modelInfo.id, default: []].append(model)
      state.modelByModelId[model.modelInfo.id] = model.modelInfo

      staleProviderModelIds.remove(model.id)
    }
    for providerModelId in staleProviderModelIds {
      guard let modelInfo = state.modelsByProviderId.removeValue(forKey: providerModelId)?.modelInfo else { continue }
      state.providerModelsByModelId[modelInfo.id]?.removeAll(where: { $0.id == providerModelId })
      if state.providerModelsByModelId[modelInfo.id]?.isEmpty == true {
        state.providerModelsByModelId.removeValue(forKey: modelInfo.id)
        state.modelByModelId.removeValue(forKey: modelInfo.id)
      }
    }
  }

  private func fetchAndSaveModelsAvailable(
    for provider: AIProvider,
    settings: AIProviderSettings)
    async throws -> [AIProviderModel]
  {
    let models = try await fetchModelsAvailable(for: provider, settings: settings)

    let llmModelByProvider = inLock { state in
      Self.set(models: models, for: provider, to: &state)
      return state.llmModelByProvider
    }

    do {
      try Self.persist(
        models: llmModelByProvider.wrappedValue.reduce(into: [:]) { $0[$1.key] = $1.value },
        fileManager: fileManager)
    } catch {
      defaultLogger.error("Failed to persist models", error)
    }
    mutableModels.send(modelByModelId.sortedValues)

    return models
  }

  private func fetchModelsAvailable(for provider: AIProvider, settings: AIProviderSettings) async throws -> [AIProviderModel] {
    if provider.isExternalAgent {
      return [.init(
        providerId: provider.id,
        provider: provider,
        modelInfo:
        .init(
          name: provider.name,
          slug: provider.id,
          contextSize: .max,
          maxOutputTokens: .max,
          defaultPricing: nil,
          createdAt: 0,
          rankForProgramming: 0))]
    }

    let apiProvider = try await Schema.APIProvider(
      provider: provider,
      settings: settings,
      shellService: shellService,
      projectRoot: nil)

    let data = try JSONEncoder().encode(Schema.ListModelsInput(provider: .init(
      name: apiProvider.name,
      settings: apiProvider.settings)))
    let response: Schema.ListModelsOutput = try await localServer.postRequest(path: "models", data: data)
    return response.models.map { AIProviderModel(
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
  }

  private func observerChangesToSettings() {
    let previousSettings = Atomic<[AIProvider: AIProviderSettings]?>(nil)
    settingsService.liveValue(for: \.llmProviderSettings).sink { @Sendable [weak self] llmProviderSettings in
      guard let self else { return }
      let previous = previousSettings.set(to: llmProviderSettings)
      Task { [weak self] in
        guard let self else { return }
        await updateModels(from: previous, to: llmProviderSettings)
        _availableModels.send(Self.availableModels(settings: llmProviderSettings, models: llmModelByProvider.wrappedValue))
      }
    }.store(in: &cancellables)
    settingsService.liveValue(for: \.enabledModels).sink { @Sendable [weak self] _ in
      guard let self else { return }
      mutableModels.send(mutableModels.value) // This will trigger a new filtering of active models
    }.store(in: &cancellables)
  }

  private func updateModels(
    from previous: [AIProvider: AIProviderSettings]?,
    to current: [AIProvider: AIProviderSettings]?)
    async
  {
    @Sendable
    func _updateModels(
      from previous: [AIProvider: AIProviderSettings]?,
      to current: [AIProvider: AIProviderSettings]?)
      async
    {
      // Remove providers that are no longer present
      let removedProviders = (previous ?? [:]).keys.filter { current?[$0] == nil }
      let modelInfos = inLock { state in
        for provider in removedProviders {
          Self.remove(provider: provider, from: &state)
        }
        return state.modelByModelId.sortedValues
      }
      mutableModels.send(modelInfos)

      // Fetch models for updated providers.
      let updatedProviders = (current ?? [:]).filter { previous?[$0.key] != $0.value }

      await withTaskGroup { group in
        for (provider, providerSettings) in updatedProviders {
          group.addTask { @Sendable in
            do {
              _ = try await self.fetchAndSaveModelsAvailable(for: provider, settings: providerSettings)
            } catch {
              defaultLogger.error("Failed to fetch models for provider \(provider.id)", error)
            }
          }
        }
        await group.waitForAll()
      }

      do {
        try Self.persist(
          models: llmModelByProvider.wrappedValue.reduce(into: [:], { $0[$1.key] = $1.value }),
          fileManager: fileManager)
      } catch {
        defaultLogger.error("Failed to persist models", error)
      }
    }
    // Ensure that those updates are serial, since they rely on the change between two states.
    await queue.queue {
      await _updateModels(from: previous, to: current)
    }.value
  }

  private func filterActiveModels(_ models: [AIModel]) -> [AIModel] {
    models.filter { model in
      settingsService.value(for: \.enabledModels).contains(model.id) ||
        // The model that represent an external agent should always be considered active.
        // To disable it, the user can disable the provider instead.
        providerModelsByModelId[model.id]?.first?.provider.isExternalAgent == true
    }
  }

}

extension PublishedDictionary<AIModelID, AIModel> {
  var sortedValues: [AIModel] {
    wrappedValue.values.sorted(by: { $0.rankForProgramming < $1.rankForProgramming })
  }
}

extension DefaultLLMService {

  var activeModels: ReadonlyCurrentValueSubject<[AIModel], Never> {
    llmModelsManager.activeModels
  }

  var availableModels: ReadonlyCurrentValueSubject<[AIModel], Never> {
    llmModelsManager.availableModels
  }

  func modelsAvailable(for provider: AIProvider) -> ReadonlyCurrentValueSubject<[AIProviderModel], Never> {
    llmModelsManager.modelsAvailable(for: provider)
  }

  func refetchModelsAvailable(
    for provider: AIProvider,
    newSettings: Settings.AIProviderSettings)
    async throws -> [AIProviderModel]
  {
    try await llmModelsManager.refetchModelsAvailable(for: provider, newSettings: newSettings)
  }

  func getModel(by providerModelId: String) -> ReadonlyCurrentValueSubject<AIProviderModel?, Never> {
    llmModelsManager.getModel(by: providerModelId)
  }

  func getModelInfo(by modelInfoId: AIModelID) -> ReadonlyCurrentValueSubject<AIModel?, Never> {
    llmModelsManager.getModelInfo(by: modelInfoId)
  }

  func provider(for model: AIModel) -> ReadonlyCurrentValueSubject<AIProvider?, Never> {
    llmModelsManager.provider(for: model)
  }

  func lowTierModel() -> AIProviderModel? {
    let settings = settingsService.values()

    // Get low tier model candidates from configured providers
    let lowTierCandidates: [(provider: AIProvider, modelInfo: AIModel)] = settings.llmProviderSettings.keys
      .compactMap { provider in
        guard
          let lowTierModelId = provider.lowTierModelId,
          let modelInfo = getModelInfo(by: lowTierModelId),
          settings.enabledModels.contains(modelInfo.id)
        else {
          return nil
        }
        return (provider, modelInfo)
      }

    // Sort by input cost (ascending) and return the cheapest
    guard
      let (provider, modelInfo) = lowTierCandidates.sorted(by: { a, b in
        let costA = a.modelInfo.defaultPricing?.input ?? .greatestFiniteMagnitude
        let costB = b.modelInfo.defaultPricing?.input ?? .greatestFiniteMagnitude
        return costA < costB
      }).first
    else {
      return nil
    }

    // Construct the AIProviderModel using the actual model from the provider
    return modelsAvailable(for: provider).first(where: { $0.modelInfo.id == modelInfo.id })
  }
}

// MARK: - PersistedAIProviderModels

struct PersistedAIProviderModels: Codable {
  init(models: [AIProvider: [AIProviderModel]]) {
    self.models = models
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let keys = container.allKeys
    var dict = [AIProvider: [AIProviderModel]]()
    for key in keys {
      let models = try container.decode([AIProviderModel].self, forKey: key)
      if let provider = AIProvider(rawValue: key) {
        dict[provider] = models
      }
    }
    models = dict
  }

  let models: [AIProvider: [AIProviderModel]]

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    for (provider, models) in models {
      try container.encode(models, forKey: provider.id)
    }
  }

}

// MARK: - PublishedDictionary

@ThreadSafe
private final class PublishedDictionary<Key: Hashable & Sendable, Value: Equatable & Sendable>: Sendable {
  init(_ wrappedValue: [Key: Value] = [:]) {
    self.wrappedValue = wrappedValue
  }

  var subscribers = [Key: [UUID: @Sendable (Value?) -> Void]]()
  var wrappedValue: [Key: Value]

  func subscribeToValue(for key: Key) -> ReadonlyCurrentValueSubject<Value?, Never> {
    let subscriptionId = UUID()
    let publisher = CurrentValueSubject<Value?, Never>(wrappedValue[key])
    let cancellable = AnyCancellable { [weak self] in
      self?.inLock { $0.subscribers[key]?.removeValue(forKey: subscriptionId) }
    }
    subscribers[key, default: [:]][subscriptionId] = { [weak publisher] model in
      publisher?.send(model)
    }
    return .init(publisher.value, publisher: publisher.retaining(cancellable).removeDuplicates().eraseToAnyPublisher())
  }

  subscript(_ key: Key) -> Value? {
    get { wrappedValue[key] }
    set {
      inLock { state in
        state.wrappedValue[key] = newValue
        state.subscribers[key]?.forEach { $0.value(newValue) }
      }
    }
  }

  subscript(_ key: Key, default defaultValue: Value) -> Value {
    get { inLock { $0.wrappedValue[key, default: defaultValue] } }
    set {
      inLock { state in
        state.wrappedValue[key] = newValue
        state.subscribers[key]?.forEach { $0.value(newValue) }
      }
    }
  }

  @discardableResult
  func removeValue(forKey key: Key) -> Value? {
    inLock { state in
      let value = state.wrappedValue.removeValue(forKey: key)
      state.subscribers[key]?.forEach { $0.value(nil) }
      return value
    }
  }

}
