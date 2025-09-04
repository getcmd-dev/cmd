// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import Foundation
import FoundationInterfaces
import LLMFoundation
import SettingsServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - SettingsViewModel

@Observable
@MainActor
public final class SettingsViewModel {
  public init() {
    @Dependency(\.settingsService) var settingsService
    self.settingsService = settingsService
    @Dependency(\.userDefaults) var userDefaults
    self.userDefaults = userDefaults
    // This one is not dependency injected. That should be ok.
    releaseUserDefaults = try? UserDefaults.releaseShared(bundle: .main)
    @Dependency(\.toolsPlugin) var toolsPlugin
    self.toolsPlugin = toolsPlugin

    let settings = settingsService.values()
    self.settings = settings

    providerSettings = settings.llmProviderSettings
    repeatLastLLMInteraction = userDefaults.bool(forKey: .repeatLastLLMInteraction)
    showOnboardingScreenAgain = !userDefaults.bool(forKey: .hasCompletedOnboardingUserDefaultsKey)
    showInternalSettingsInRelease = releaseUserDefaults?.bool(forKey: .showInternalSettingsInRelease) == true
    defaultChatPositionIsInverted = userDefaults.bool(forKey: .defaultChatPositionIsInverted)
    enableAnalyticsAndCrashReporting = userDefaults.bool(forKey: .enableAnalyticsAndCrashReporting)

    toolConfigurationViewModel = ToolConfigurationViewModel(
      settingsService: settingsService,
      toolsPlugin: toolsPlugin)

    settingsService.liveValues()
      .receive(on: RunLoop.main)
      .sink { [weak self] newSettings in
        self?.settings = newSettings
      }
      .store(in: &cancellables)
  }

  public let toolConfigurationViewModel: ToolConfigurationViewModel

  // MARK: - Initialization

  public var providerSettings: AllLLMProviderSettings {
    didSet {
      settings.llmProviderSettings = providerSettings
      settingsService.update(setting: \.llmProviderSettings, to: providerSettings)
    }
  }

  private(set) var settings: SettingsServiceInterface.Settings

  var allowAnonymousAnalytics: Bool {
    get {
      settings.allowAnonymousAnalytics
    }
    set {
      settings.allowAnonymousAnalytics = newValue
      settingsService.update(setting: \.allowAnonymousAnalytics, to: newValue)
    }
  }

  var automaticallyCheckForUpdates: Bool {
    get {
      settings.automaticallyCheckForUpdates
    }
    set {
      settings.automaticallyCheckForUpdates = newValue
      settingsService.update(setting: \.automaticallyCheckForUpdates, to: newValue)
    }
  }

  var fileEditMode: FileEditMode {
    get {
      settings.fileEditMode
    }
    set {
      settings.fileEditMode = newValue
      settingsService.update(setting: \.fileEditMode, to: newValue)
    }
  }

  // MARK: - Internal settings
  var repeatLastLLMInteraction: Bool {
    didSet {
      userDefaults.set(repeatLastLLMInteraction, forKey: .repeatLastLLMInteraction)
    }
  }

  var showOnboardingScreenAgain: Bool {
    didSet {
      userDefaults.set(!showOnboardingScreenAgain, forKey: .hasCompletedOnboardingUserDefaultsKey)
      if showOnboardingScreenAgain {
        LLMProvider.allCases
          .compactMap(\.externalAgent)
          .forEach {
            $0.unmarkHasBeenEnabledOnce()
          }
      }
    }
  }

  var showInternalSettingsInRelease: Bool {
    didSet {
      releaseUserDefaults?.set(showInternalSettingsInRelease, forKey: .showInternalSettingsInRelease)
    }
  }

  var pointReleaseXcodeExtensionToDebugApp: Bool {
    get {
      settings.pointReleaseXcodeExtensionToDebugApp
    }
    set {
      settings.pointReleaseXcodeExtensionToDebugApp = newValue
      settingsService.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: newValue)
    }
  }

  var defaultChatPositionIsInverted: Bool {
    didSet {
      userDefaults.set(defaultChatPositionIsInverted, forKey: .defaultChatPositionIsInverted)
    }
  }

  var enableAnalyticsAndCrashReporting: Bool {
    didSet {
      userDefaults.set(enableAnalyticsAndCrashReporting, forKey: .enableAnalyticsAndCrashReporting)
    }
  }

  /// For each available model, the associated provider.
  var providerForModels: [LLMModel: LLMProvider] {
    get {
      var providerForModels = [LLMModel: LLMProvider]()
      for model in availableModels {
        providerForModels[model] = (try? settings.provider(for: model).0) ?? .anthropic
      }
      for (key, value) in settings.preferedProviders {
        providerForModels[key] = value
      }

      return providerForModels
    }
    set {
      let oldValue = providerForModels
      for (model, provider) in newValue {
        if oldValue[model] != provider {
          settings.preferedProviders[model] = provider
        }
      }
      settingsService.update(setting: \.preferedProviders, to: settings.preferedProviders)
    }
  }

  /// Reasoning settings for the model that suport reasoning.
  var reasoningModels: [LLMModel: LLMReasoningSetting] {
    get {
      var reasoningModels = [LLMModel: LLMReasoningSetting]()
      for model in availableModels.filter(\.canReason) {
        reasoningModels[model] = .init(isEnabled: false) // Default to disabled for all models
      }
      for (key, value) in settings.reasoningModels {
        reasoningModels[key] = value
      }
      return reasoningModels
    }
    set {
      let oldValue = settings.reasoningModels
      for (model, provider) in newValue {
        if oldValue[model] != provider {
          settings.reasoningModels[model] = provider
        }
      }
      settingsService.update(setting: \.reasoningModels, to: settings.reasoningModels)
    }
  }

  var inactiveModels: [LLMModel] {
    get {
      settings.inactiveModels
    }
    set {
      settings.inactiveModels = newValue
      settingsService.update(setting: \.inactiveModels, to: newValue)
    }
  }

  var customInstructions: SettingsServiceInterface.Settings.CustomInstructions {
    get {
      settings.customInstructions
    }
    set {
      settings.customInstructions = newValue
      settingsService.update(setting: \.customInstructions, to: newValue)
    }
  }

  // MARK: - Keyboard Shortcuts
  var keyboardShortcuts: SettingsServiceInterface.Settings.KeyboardShortcuts {
    get { settings.keyboardShortcuts }
    set {
      settings.keyboardShortcuts = newValue
      settingsService.update(setting: \.keyboardShortcuts, to: newValue)
    }
  }

  /// All the models that are available, based on the available providers.
  var availableModels: [LLMModel] {
    settings.availableModels
  }

  /// The LLM providers that have been configured.
  var availableProviders: [LLMProvider] {
    Array(settings.llmProviderSettings.keys)
  }

  private var cancellables = Set<AnyCancellable>()

  private let settingsService: SettingsService
  private let userDefaults: UserDefaultsI
  private let releaseUserDefaults: UserDefaultsI?
  private let toolsPlugin: ToolsPlugin
}

public typealias AllLLMProviderSettings = [LLMProvider: LLMProviderSettings]
extension AllLLMProviderSettings {
  var nextCreatedOrder: Int {
    (values.map(\.createdOrder).max() ?? 0) + 1
  }
}
