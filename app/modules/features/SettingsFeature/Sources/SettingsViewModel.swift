// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import Foundation
import FoundationInterfaces
import LLMFoundation
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

    if
      let storedLevel = userDefaults.string(forKey: .defaultLogLevel),
      let level = LogLevel(rawValue: storedLevel)
    {
      defaultLogLevel = level
    } else {
      defaultLogLevel = .info
    }

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

  public let llmSettings = LLMSettingsViewModel()

  public let toolConfigurationViewModel: ToolConfigurationViewModel

  // MARK: - Initialization

  public var providerSettings: AllAIProviderSettings {
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
        AIProvider.allCases
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

  var defaultLogLevel: LogLevel {
    didSet {
      userDefaults.set(defaultLogLevel.rawValue, forKey: .defaultLogLevel)
      settings.defaultLogLevel = defaultLogLevel
      settingsService.update(setting: \.defaultLogLevel, to: defaultLogLevel)
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

  private var cancellables = Set<AnyCancellable>()

  private let settingsService: SettingsService
  private let userDefaults: UserDefaultsI
  private let releaseUserDefaults: UserDefaultsI?
  private let toolsPlugin: ToolsPlugin
  private let xcodeController: XcodeController
}
