// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import LLMFoundation
import LLMServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface
import SwiftUI

// MARK: - LLMSettingsViewModel

/// Manages all settings related to AI providers and models, and persists changes when needed.
@Observable
@MainActor
public final class LLMSettingsViewModel {
  /// Initializes the view model by loading current settings and subscribing to live updates.
  public init() {
    @Dependency(\.settingsService) var settingsService
    self.settingsService = settingsService
    @Dependency(\.llmService) var llmService
    self.llmService = llmService

    let settings = settingsService.values()

    providerSettings = settings.llmProviderSettings
    enabledModels = settings.enabledModels
    preferedProviders = settings.preferedProviders
    reasoningModels = settings.reasoningModels

    settingsService.liveValues()
      .map({ LLMSettings(
        enabledModels: $0.enabledModels,
        providerSettings: $0.llmProviderSettings,
        preferedProviders: $0.preferedProviders,
        reasoningModels: $0.reasoningModels) })
      .removeDuplicates()
      .sink { @Sendable [weak self] llmSettings in
        Task { @MainActor in
          guard let self else { return }
          if self.providerSettings != llmSettings.providerSettings {
            self.providerSettings = llmSettings.providerSettings
          }
          if self.enabledModels != llmSettings.enabledModels {
            self.enabledModels = llmSettings.enabledModels
          }
          if self.preferedProviders != llmSettings.preferedProviders {
            self.preferedProviders = llmSettings.preferedProviders
          }
          if self.reasoningModels != llmSettings.reasoningModels {
            self.reasoningModels = llmSettings.reasoningModels
          }
        }
      }.store(in: &cancellables)
  }

  /// Settings for each configured AI provider.
  private(set) var providerSettings: [AIProvider: AIProviderSettings]

  /// List of model IDs that are currently enabled.
  private(set) var enabledModels: [AIModelID]

  /// Reasoning settings for the model that suport reasoning.
  private(set) var reasoningModels: [AIModelID: LLMReasoningSetting]

  /// For each available model, the associated provider.
  var providerForModels: [AIModel: AIProvider] {
    get { // TODO: cache this computation? Do if when the value changes in settings.
      var providerForModels = [AIModel: AIProvider]()
      for model in availableModels {
        providerForModels[model] = llmService.provider(for: model) ?? .anthropic
      }
      for (modelId, value) in preferedProviders {
        if let model = llmService.getModelInfo(by: modelId) {
          providerForModels[model] = value
        }
      }

      return providerForModels
    }
    set {
      settingsService.update(setting: \.preferedProviders, to: newValue.reduce(into: [:]) { $0[$1.key.id] = $1.value })
    }
  }

  /// Returns all models that are available based on the configured providers.
  var availableModels: [AIModel] {
    let models = providerSettings.keys.flatMap { provider in
      llmService.modelsAvailable(for: provider)
    }.reduce(into: Set<AIModel>(), { acc, value in
      acc.insert(value.modelInfo)
    })
    return Array(models)
  }

  /// Returns the list of LLM providers that have been configured.
  var availableProviders: [AIProvider] {
    Array(providerSettings.keys)
  }

  /// Enables reasoning mode for the specified model and persists the change.
  func enableReasoning(for model: AIModel) {
    reasoningModels[model.id] = .init(isEnabled: true)
    settingsService.update(setting: \.reasoningModels, to: reasoningModels)
  }

  /// Disables reasoning mode for the specified model and persists the change.
  func disableReasoning(for model: AIModel) {
    reasoningModels.removeValue(forKey: model.id)
    settingsService.update(setting: \.reasoningModels, to: reasoningModels)
  }

  /// Enables the specified model and persists the change.
  func enable(model: AIModel) {
    enabledModels.append(model.id)
    settingsService.update(setting: \.enabledModels, to: enabledModels)
  }

  /// Disables the specified model and persists the change.
  func disable(model: AIModel) {
    enabledModels.removeAll(where: { $0 == model.id })
    settingsService.update(setting: \.enabledModels, to: enabledModels)
  }

  /// Saves provider settings, refetches available models, and enables default models for new providers.
  func save(providerSettings: AIProviderSettings, for provider: AIProvider) {
    let isNew = self.providerSettings[provider] == nil
    self.providerSettings[provider] = providerSettings
    settingsService.update(setting: \.llmProviderSettings, to: self.providerSettings)

    Task {
      do {
        _ = try await llmService.refetchModelsAvailable(for: provider, newSettings: providerSettings)
        if isNew {
          // Enable default models.
          for modelId in provider.modelsEnabledByDefault {
            if let model = llmService.getModelInfo(by: modelId), !enabledModels.contains(modelId) {
              enable(model: model)
            }
          }
        }
      } catch {
        defaultLogger.error("Failed to fetch AI provider models after updating settings", error)
      }
    }
  }

  /// Removes the specified provider and its settings.
  func remove(provider: AIProvider) {
    providerSettings.removeValue(forKey: provider)
    settingsService.update(setting: \.llmProviderSettings, to: providerSettings)
  }

  /// Returns the list of models available for the specified provider.
  func modelsAvailable(for provider: AIProvider) -> ObservableValue<[AIProviderModel]> {
    llmService.modelsAvailable(for: provider).asObservableValue()
  }

  /// Returns the list of providers that support the specified model.
  func providersAvailable(for model: AIModel) -> [AIProvider] {
    availableProviders.filter { provider in
      llmService.modelsAvailable(for: provider).contains(where: { $0.modelInfo.id == model.id })
    }
  }

  /// Returns a binding to the provider for the specified model.
  func provider(for model: AIModel) -> Binding<AIProvider> {
    .init(get: {
      self.providerForModels[model] ?? AIProvider.openAI
    }, set: { provider in
      self.providerForModels[model] = provider
    })
  }

  /// Returns a binding to the enabled state of the specified model.
  func isActive(for model: AIModel) -> Binding<Bool> {
    .init(get: {
      self.enabledModels.contains(model.id)
    }, set: { isActive in
      if isActive {
        self.enable(model: model)
      } else {
        self.disable(model: model)
      }
    })
  }

  /// Returns a binding to the reasoning settings for the specified model, or nil if the model doesn't support reasoning.
  func reasoningSetting(for model: AIModel) -> Binding<LLMReasoningSetting>? {
    guard model.canReason else { return nil }
    return .init(
      get: { self.reasoningModels[model.id] ?? .init(isEnabled: false) },
      set: { reasoningSettings in
        if reasoningSettings.isEnabled {
          self.enableReasoning(for: model)
        } else {
          self.disableReasoning(for: model)
        }
      })
  }

  /// Maps model IDs to their preferred provider.
  private var preferedProviders: [AIModelID: AIProvider]

  /// Service for persisting and retrieving settings.
  private let settingsService: SettingsService

  /// Stores cancellables for Combine subscriptions.
  private var cancellables = Set<AnyCancellable>()

  /// Service for interacting with LLM providers and models.
  private let llmService: LLMService

}

public typealias AllAIProviderSettings = [AIProvider: AIProviderSettings]
extension AllAIProviderSettings {
  var nextCreatedOrder: Int {
    (values.map(\.createdOrder).max() ?? 0) + 1
  }
}

extension SettingsServiceInterface.Settings {
  func preferedProviders(llmService: LLMService) -> [AIModel: AIProvider] {
    preferedProviders.reduce(into: [AIModel: AIProvider]()) { acc, el in
      guard let model = llmService.getModelInfo(by: el.key) else { return }
      acc[model] = el.value
    }
  }
}

// MARK: - LLMSettings

private struct LLMSettings: Sendable, Equatable {
  let enabledModels: [AIModelID]
  let providerSettings: [AIProvider: AIProviderSettings]
  let preferedProviders: [AIModelID: AIProvider]
  let reasoningModels: [AIModelID: LLMReasoningSetting]
}
