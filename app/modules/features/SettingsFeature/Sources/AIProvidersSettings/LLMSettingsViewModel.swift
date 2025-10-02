// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import Dependencies
import Foundation
import LLMFoundation
import LLMServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface
import SwiftUI

// MARK: - LLMSettingsViewModel

@Observable
@MainActor
public final class LLMSettingsViewModel {
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
          if self.reasoningModels != llmSettings.reasoningModels { [
            self.reasoningModels = llmSettings.reasoningModels,
          ] }
        }
      }.store(in: &cancellables)
  }

  private(set) var providerSettings: [LLMProvider: LLMProviderSettings]

  private(set) var enabledModels: [ModelInfoId]

  /// Reasoning settings for the model that suport reasoning.
  private(set) var reasoningModels: [ModelInfoId: LLMReasoningSetting]

  /// For each available model, the associated provider.
  var providerForModels: [LLMModelInfo: LLMProvider] {
    get { // TODO: cache this computation? Do if when the value changes in settings.
      var providerForModels = [LLMModelInfo: LLMProvider]()
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

  /// All the models that are available, based on the available providers.
  var availableModels: [LLMModelInfo] {
    let models = providerSettings.keys.flatMap { provider in
      llmService.modelsAvailable(for: provider)
    }.reduce(into: Set<LLMModelInfo>(), { acc, value in
      acc.insert(value.modelInfo)
    })
    return Array(models)
  }

  /// The LLM providers that have been configured.
  var availableProviders: [LLMProvider] {
    Array(providerSettings.keys)
  }

  func enableReasoning(for model: LLMModelInfo) {
    reasoningModels[model.id] = .init(isEnabled: true)
    settingsService.update(setting: \.reasoningModels, to: reasoningModels)
  }

  func disableReasoning(for model: LLMModelInfo) {
    reasoningModels.removeValue(forKey: model.id)
    settingsService.update(setting: \.reasoningModels, to: reasoningModels)
  }

  func enable(model: LLMModelInfo) {
    enabledModels.append(model.id)
    settingsService.update(setting: \.enabledModels, to: enabledModels)
  }

  func disable(model: LLMModelInfo) {
    enabledModels.removeAll(where: { $0 == model.id })
    settingsService.update(setting: \.enabledModels, to: enabledModels)
  }

  func save(providerSettings: LLMProviderSettings, for provider: LLMProvider) {
    self.providerSettings[provider] = providerSettings
    settingsService.update(setting: \.llmProviderSettings, to: self.providerSettings)

    Task {
      do {
        _ = try await llmService.refetchModelsAvailable(for: provider, newSettings: providerSettings)
      } catch {
        defaultLogger.error("Failed to fetch AI provider models after updating settings", error)
      }
    }
  }

  func remove(provider: LLMProvider) {
    providerSettings.removeValue(forKey: provider)
    settingsService.update(setting: \.llmProviderSettings, to: providerSettings)
  }

  func modelsAvailable(for provider: LLMProvider) -> [LLMModel] {
    llmService.modelsAvailable(for: provider)
  }

  func providersAvailable(for model: LLMModelInfo) -> [LLMProvider] {
    availableProviders.filter { provider in
      llmService.modelsAvailable(for: provider).contains(where: { $0.modelInfo.id == model.id })
    }
  }

  func provider(for model: LLMModelInfo) -> Binding<LLMProvider> {
    .init(get: {
      self.providerForModels[model] ?? LLMProvider.openAI
    }, set: { provider in
      self.providerForModels[model] = provider
    })
  }

  func isActive(for model: LLMModelInfo) -> Binding<Bool> {
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

  func reasoningSetting(for model: LLMModelInfo) -> Binding<LLMReasoningSetting>? {
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

  private var preferedProviders: [ModelInfoId: LLMProvider]

  private let settingsService: SettingsService

  private var cancellables = Set<AnyCancellable>()

  private let llmService: LLMService

}

public typealias AllLLMProviderSettings = [LLMProvider: LLMProviderSettings]
extension AllLLMProviderSettings {
  var nextCreatedOrder: Int {
    (values.map(\.createdOrder).max() ?? 0) + 1
  }
}

extension SettingsServiceInterface.Settings {
  func preferedProviders(llmService: LLMService) -> [LLMModelInfo: LLMProvider] {
    preferedProviders.reduce(into: [LLMModelInfo: LLMProvider]()) { acc, el in
      guard let model = llmService.getModelInfo(by: el.key) else { return }
      acc[model] = el.value
    }
  }
}

// MARK: - LLMSettings

private struct LLMSettings: Sendable, Equatable {
  let enabledModels: [ModelInfoId]
  let providerSettings: [LLMProvider: LLMProviderSettings]
  let preferedProviders: [ModelInfoId: LLMProvider]
  let reasoningModels: [ModelInfoId: LLMReasoningSetting]
}
