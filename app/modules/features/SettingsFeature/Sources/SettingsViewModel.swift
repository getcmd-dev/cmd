// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import Foundation
import FoundationInterfaces
import LLMFoundation
import LLMServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface
import SharedValuesFoundation
import SwiftUI
import ToolFoundation
import XcodeControllerServiceInterface

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
    @Dependency(\.xcodeController) var xcodeController
    self.xcodeController = xcodeController
    @Dependency(\.llmService) var llmService
    self.llmService = llmService

    let settings = settingsService.values()
    self.settings = settings

    providerSettings = settings.llmProviderSettings
    repeatLastLLMInteraction = userDefaults.bool(forKey: .repeatLastLLMInteraction)
    showOnboardingScreenAgain = !userDefaults.bool(forKey: .hasCompletedOnboardingUserDefaultsKey)
    showInternalSettingsInRelease = releaseUserDefaults?.bool(forKey: .showInternalSettingsInRelease) == true
    defaultChatPositionIsInverted = userDefaults.bool(forKey: .defaultChatPositionIsInverted)
    enableAnalyticsAndCrashReporting = userDefaults.bool(forKey: .enableAnalyticsAndCrashReporting)
    enableNetworkProxy = userDefaults.bool(forKey: .enableNetworkProxy)
    showToolInputCopyButtonInRelease = userDefaults.bool(forKey: .showToolInputCopyButtonInRelease)

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

  let llmService: LLMService

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

  var enableNetworkProxy: Bool {
    didSet {
      userDefaults.set(enableNetworkProxy, forKey: .enableNetworkProxy)
    }
  }

  var showToolInputCopyButtonInRelease: Bool {
    didSet {
      userDefaults.set(showToolInputCopyButtonInRelease, forKey: .showToolInputCopyButtonInRelease)
    }
  }

  /// For each available model, the associated provider.
  var providerForModels: [LLMModelInfo: LLMProvider] {
    get {
      var providerForModels = [LLMModelInfo: LLMProvider]()
      for model in availableModels {
        providerForModels[model] = llmService.provider(for: model) ?? .anthropic
      }
      for (key, value) in settings.preferedProviders(llmService: llmService) {
        providerForModels[key] = value
      }

      return providerForModels
    }
    set {
      let oldValue = providerForModels
      for (model, provider) in newValue {
        if oldValue[model] != provider {
          settings.preferedProviders[model.id] = provider
        }
      }
      settingsService.update(setting: \.preferedProviders, to: settings.preferedProviders)
    }
  }

  /// Reasoning settings for the model that suport reasoning.
  var reasoningModels: [LLMModelInfo: LLMReasoningSetting] {
    get {
      [:] // TODO
//      var reasoningModels = [LLMModelInfo: LLMReasoningSetting]()
//      for model in availableModels.filter(\.canReason) {
//        reasoningModels[model] = .init(isEnabled: false) // Default to disabled for all models
//      }
//      for (key, value) in settings.reasoningModels {
//        reasoningModels[key] = value
//      }
//      return reasoningModels
    }
    set {
      // TODO
//      let oldValue = settings.reasoningModels
//      for (model, provider) in newValue {
//        if oldValue[model] != provider {
//          settings.reasoningModels[model] = provider
//        }
//      }
//      settingsService.update(setting: \.reasoningModels, to: settings.reasoningModels)
    }
  }

//  var inactiveModels: [LLMModelInfo] {
//    get {
//      settings.inactiveModels
//    }
//    set {
//      settings.inactiveModels = newValue
//      settingsService.update(setting: \.inactiveModels, to: newValue)
//    }
//  }

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

  // MARK: - User Defined Xcode Shortcuts
  var userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut] {
    get { settings.userDefinedXcodeShortcuts }
    set {
      let oldValue = settings.userDefinedXcodeShortcuts
      settings.userDefinedXcodeShortcuts = newValue
      settingsService.update(setting: \.userDefinedXcodeShortcuts, to: newValue)

      // Trigger extension reload if shortcuts changed
      if oldValue != newValue {
        Task {
          do {
            try await xcodeController.executeExtensionCommand(ExtensionCommandNames.reloadSettings)
            defaultLogger.log("Successfully triggered extension reload after user defined shortcuts change")
          } catch {
            defaultLogger.error("Failed to trigger extension reload: \(error)")
          }
        }
      }
    }
  }

  // MARK: - MCP Servers
  var mcpServers: [String: MCPServerConfiguration] {
    get { settings.mcpServers }
    set {
      settings.mcpServers = newValue
      settingsService.update(setting: \.mcpServers, to: newValue)
    }
  }

  /// All the models that are available, based on the available providers.
  var availableModels: [LLMModelInfo] {
    let models = settings.llmProviderSettings.keys.flatMap { provider in
      llmService.listModelAvailable(for: provider)
    }.reduce(into: Set<LLMModelInfo>(), { acc, value in
      acc.insert(value.modelInfo)
    })
    return Array(models)
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
  private let xcodeController: XcodeController
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
