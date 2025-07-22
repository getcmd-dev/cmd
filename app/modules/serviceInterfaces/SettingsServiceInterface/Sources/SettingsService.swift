// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import LLMFoundation

// MARK: - FileEditMode

public enum FileEditMode: String, Sendable, Codable, Equatable, CaseIterable {
  case directIO = "direct I/O"
  case xcodeExtension = "Xcode Extension"

  public var description: String {
    switch self {
    case .directIO:
      """
      Direct I/O - Modify files directly on disk.
      + simplest and non disruptive.
      - does not work with unsaved changes in Xcode, and does not maintain edit history.
      """

    case .xcodeExtension:
      """
      Xcode Extension - Modify the file through Xcode.
      + consistent with unsaved changes and maintain edit history.
      - activate Xcode and bring the file in focus, which can be disruptive.
      """
    }
  }
}

// MARK: - LLMReasoningSetting

public struct LLMReasoningSetting: Sendable, Equatable {
  public var isEnabled: Bool
  public init(isEnabled: Bool) {
    self.isEnabled = isEnabled
  }
}

// MARK: - Settings

public struct Settings: Sendable, Equatable {
  public init(
    pointReleaseXcodeExtensionToDebugApp: Bool,
    allowAnonymousAnalytics: Bool = false,
    automaticallyCheckForUpdates: Bool = true,
    fileEditMode: FileEditMode = .directIO,
    preferedProviders: [LLMModel: LLMProvider] = [:],
    llmProviderSettings: [LLMProvider: LLMProviderSettings] = [:],
    inactiveModels: [LLMModel] = [],
    reasoningModels: [LLMModel: LLMReasoningSetting] = [:],
    customInstructions: CustomInstructions = CustomInstructions(),
    toolPreferences: [ToolPreference] = [])
  {
    self.pointReleaseXcodeExtensionToDebugApp = pointReleaseXcodeExtensionToDebugApp
    self.allowAnonymousAnalytics = allowAnonymousAnalytics
    self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
    self.fileEditMode = fileEditMode
    self.preferedProviders = preferedProviders
    self.llmProviderSettings = llmProviderSettings
    self.inactiveModels = inactiveModels
    self.reasoningModels = reasoningModels
    self.customInstructions = customInstructions
    self.toolPreferences = toolPreferences
  }

  public struct LLMProviderSettings: Sendable, Codable, Equatable {
    /// To help keep track of which Provider was setup first, we use an incrementing order.
    /// This order can be useful for determining which provider to default to when multiple are available.
    public let createdOrder: Int
    public var apiKey: String
    public var baseUrl: String?
    public var executable: String?

    public init(
      apiKey: String,
      baseUrl: String?,
      executable: String?,
      createdOrder: Int)
    {
      self.apiKey = apiKey
      self.baseUrl = baseUrl
      self.executable = executable
      self.createdOrder = createdOrder
    }
  }

  public struct CustomInstructions: Sendable, Codable, Equatable {
    public var askMode: String?
    public var agentMode: String?

    public init(askModePrompt: String? = nil, agentModePrompt: String? = nil) {
      askMode = askModePrompt
      agentMode = agentModePrompt
    }
  }

  public struct ToolPreference: Sendable, Codable, Equatable {
    public let toolName: String
    public var alwaysApprove: Bool

    public init(toolName: String, alwaysApprove: Bool = false) {
      self.toolName = toolName
      self.alwaysApprove = alwaysApprove
    }
  }

  public var allowAnonymousAnalytics: Bool
  public var pointReleaseXcodeExtensionToDebugApp: Bool
  public var automaticallyCheckForUpdates: Bool
  public var fileEditMode: FileEditMode
  // LLM settings
  public var preferedProviders: [LLMModel: LLMProvider]
  public var llmProviderSettings: [LLMProvider: LLMProviderSettings]
  public var reasoningModels: [LLMModel: LLMReasoningSetting]

  public var inactiveModels: [LLMModel]
  public var customInstructions: CustomInstructions
  public var toolPreferences: [ToolPreference]

}

// MARK: - Settings + Tool Preferences Helpers

extension Settings {
  public func toolPreference(for toolName: String) -> ToolPreference? {
    toolPreferences.first { $0.toolName == toolName }
  }

  public mutating func setToolPreference(toolName: String, alwaysApprove: Bool) {
    if let index = toolPreferences.firstIndex(where: { $0.toolName == toolName }) {
      toolPreferences[index].alwaysApprove = alwaysApprove
    } else {
      toolPreferences.append(ToolPreference(toolName: toolName, alwaysApprove: alwaysApprove))
    }
  }

  public func shouldAlwaysApprove(toolName: String) -> Bool {
    toolPreferences.first { $0.toolName == toolName }?.alwaysApprove ?? false
  }
}

public typealias LLMProviderSettings = Settings.LLMProviderSettings

// MARK: - SettingsService

public protocol SettingsService: Sendable {
  /// Get the current value of a setting.
  func value<T: Equatable>(for keypath: KeyPath<Settings, T>) -> T
  /// Get the current value of a setting as a live value.
  func liveValue<T: Equatable>(for keypath: KeyPath<Settings, T>) -> ReadonlyCurrentValueSubject<T, Never>

  /// Get all settings.
  func values() -> Settings

  /// Get all settings as a live value.
  func liveValues() -> ReadonlyCurrentValueSubject<Settings, Never>

  /// Update the value of a setting
  func update<T: Equatable>(setting: WritableKeyPath<Settings, T>, to value: T)

  /// Update the value of a setting
  func update(to settings: Settings)

  /// Reset a setting to its default value
  func resetToDefault(setting: WritableKeyPath<Settings, some Equatable>)

  /// Reset all settings to their default values
  func resetAllToDefault()
}

// MARK: - SettingsServiceProviding

public protocol SettingsServiceProviding {
  var settingsService: SettingsService { get }
}

public typealias UserDefaultsKey = String

extension UserDefaultsKey {
  public static let hasCompletedOnboardingUserDefaultsKey = "hasCompletedOnboarding"
  public static let showInternalSettingsInRelease = "showInternalSettingsInRelease"
  public static let defaultChatPositionIsInverted = "defaultChatPositionIsInverted"
  public static let repeatLastLLMInteraction = "llmService.isRepeating"
}
