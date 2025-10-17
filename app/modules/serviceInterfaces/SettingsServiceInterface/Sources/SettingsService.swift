// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import LLMFoundation
import LoggingServiceInterface
import SwiftUI

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
    pointReleaseXcodeExtensionToDebugApp: Bool = false,
    allowAnonymousAnalytics: Bool = false,
    automaticallyCheckForUpdates: Bool = true,
    automaticallyUpdateXcodeSettings: Bool = false,
    fileEditMode: FileEditMode = .directIO,
    preferedProviders: [AIModelID: AIProvider] = [:],
    llmProviderSettings: [AIProvider: AIProviderSettings] = [:],
    enabledModels: [AIModelID] = [],
    reasoningModels: [AIModelID: LLMReasoningSetting] = [:],
    chatModeConfigurations: [String: ChatModeConfiguration] = [:],
    knownToolReferenceIds: [String] = [],
    toolPreferences: [ToolPreference] = [],
    keyboardShortcuts: KeyboardShortcuts = KeyboardShortcuts(),
    userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut] = [],
    mcpServers: [String: MCPServerConfiguration] = [:],
    defaultLogLevel: LogLevel = .info)
  {
    self.pointReleaseXcodeExtensionToDebugApp = pointReleaseXcodeExtensionToDebugApp
    self.allowAnonymousAnalytics = allowAnonymousAnalytics
    self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
    self.automaticallyUpdateXcodeSettings = automaticallyUpdateXcodeSettings
    self.fileEditMode = fileEditMode
    self.preferedProviders = preferedProviders.filter { llmProviderSettings[$0.value] != nil }
    self.llmProviderSettings = llmProviderSettings
    self.enabledModels = enabledModels
    self.reasoningModels = reasoningModels
    self.chatModeConfigurations = chatModeConfigurations
    self.knownToolReferenceIds = knownToolReferenceIds
    self.toolPreferences = toolPreferences
    self.keyboardShortcuts = keyboardShortcuts
    self.userDefinedXcodeShortcuts = userDefinedXcodeShortcuts
    self.mcpServers = mcpServers
    self.defaultLogLevel = defaultLogLevel
  }

  public struct AIProviderSettings: Sendable, Codable, Equatable {
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

  public struct ChatModeConfiguration: Sendable, Equatable {
    public var customInstructions: String?
    /// List of tool reference IDs available in this mode.
    /// When nil, use default tools from toolsPlugin.defaultTools(for:)
    /// When set to an array (even empty), use exactly those tools.
    public var availableToolIds: [String]?

    public init(customInstructions: String? = nil, availableToolIds: [String]? = nil) {
      self.customInstructions = customInstructions
      self.availableToolIds = availableToolIds
    }
  }

  public struct ToolPreference: Sendable, Equatable, Codable {
    public init(toolReferenceId: String, alwaysApprove: Bool = false) {
      self.toolReferenceId = toolReferenceId
      self.alwaysApprove = alwaysApprove
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      alwaysApprove = try container.decode(Bool.self, forKey: .alwaysApprove)

      // TODO: remove fallback after 11/15/25
      // Try to decode toolId first, fall back to toolName for backward compatibility
      if let toolReferenceId = try? container.decode(String.self, forKey: .toolId) {
        self.toolReferenceId = toolReferenceId
      } else if let toolName = try? container.decode(String.self, forKey: .toolName) {
        toolReferenceId = toolName
      } else {
        throw DecodingError.keyNotFound(
          CodingKeys.toolId,
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Neither 'toolId' nor 'toolName' key found"))
      }
    }

    public let toolReferenceId: String
    public var alwaysApprove: Bool

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(toolReferenceId, forKey: .toolId)
      try container.encode(alwaysApprove, forKey: .alwaysApprove)
    }

    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
      // This encodes the tool referenceId, which merges tools from different providers (eg edit file from cmd / Claude Code etc)
      // As this key is used facing (it shows up in the local settings file) we simply use toolId here.
      case toolId
      case toolName
      case alwaysApprove
    }

  }

  public var allowAnonymousAnalytics: Bool
  public var pointReleaseXcodeExtensionToDebugApp: Bool
  public var automaticallyCheckForUpdates: Bool
  /// Whether to automatically update Xcode settings to configure `cmd` as an AI backend.
  public var automaticallyUpdateXcodeSettings: Bool
  public var fileEditMode: FileEditMode
  // LLM settings
  public var preferedProviders: [AIModelID: AIProvider]
  public var reasoningModels: [AIModelID: LLMReasoningSetting]

  public var enabledModels: [AIModelID]
  public var chatModeConfigurations: [String: ChatModeConfiguration]
  /// Array of known tool reference IDs. This is internal state for tracking tools.
  public var knownToolReferenceIds: [String]
  public var toolPreferences: [ToolPreference]
  public var keyboardShortcuts: KeyboardShortcuts
  public var userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut]
  public var mcpServers: [String: MCPServerConfiguration]

  public var defaultLogLevel: LogLevel

  public var llmProviderSettings: [AIProvider: AIProviderSettings] {
    didSet {
      // Ensure we don't keep prefered providers that are no longer configured.
      preferedProviders = preferedProviders.filter { llmProviderSettings[$0.value] != nil }
    }
  }

}

// MARK: - Settings + Tool Preferences Helpers

extension Settings {
  public func toolPreference(for toolReferenceId: String) -> ToolPreference? {
    toolPreferences.first { $0.toolReferenceId == toolReferenceId }
  }

  public mutating func setToolPreference(toolReferenceId: String, alwaysApprove: Bool) {
    if let index = toolPreferences.firstIndex(where: { $0.toolReferenceId == toolReferenceId }) {
      toolPreferences[index].alwaysApprove = alwaysApprove
    } else {
      toolPreferences.append(ToolPreference(toolReferenceId: toolReferenceId, alwaysApprove: alwaysApprove))
    }
  }

  public func shouldAlwaysApprove(toolReferenceId: String) -> Bool {
    toolPreferences.first { $0.toolReferenceId == toolReferenceId }?.alwaysApprove ?? false
  }
}

public typealias AIProviderSettings = Settings.AIProviderSettings

// MARK: - UserDefinedXcodeShortcut

public struct UserDefinedXcodeShortcut: Sendable, Codable, Equatable, Identifiable {
  public init(
    id: UUID = UUID(),
    name: String,
    command: String,
    keyBinding: Settings.KeyboardShortcut? = nil,
    xcodeCommandIndex: Int)
  {
    self.id = id
    self.name = name
    self.command = command
    self.keyBinding = keyBinding
    self.xcodeCommandIndex = xcodeCommandIndex
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      name: container.decode(String.self, forKey: .name),
      command: container.decode(String.self, forKey: .command),
      xcodeCommandIndex: container.decode(Int.self, forKey: .xcodeCommandIndex))
  }

  /// A transient ID that makes the shortcut identifiable. It is not persisted.
  public let id: UUID
  /// The name of the Xcode shortcut. This will be displayed in Xcode's menu.
  public var name: String
  /// The command to run when the shortcut is triggered.
  public var command: String

  public var keyBinding: Settings.KeyboardShortcut?
  /// The index of the Xcode command this shortcut is associated with.
  /// Xcode identifies commands by the class name they are mapped to (e.g. `UserDefinedXcodeShortcut0Command` for index 0).
  /// We keep track to this index to keep it consistently associated with the same command.
  public let xcodeCommandIndex: Int

  public func encode(to encoder: any Encoder) throws {
    // The id is not encoded. It is only used in memory to help identify
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(command, forKey: .command)
    // keyBinding is not encoded as it is not yet supported
    try container.encode(xcodeCommandIndex, forKey: .xcodeCommandIndex)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case command
    case keyBinding
    case xcodeCommandIndex
  }
}

// MARK: - Keyboard Shortcuts

extension Settings {

  public typealias KeyboardShortcuts = [KeyboardShortcutKey: KeyboardShortcut]

  public struct KeyboardShortcut: Sendable, Codable, Equatable {
    public let key: KeyEquivalent
    public let modifiers: [KeyModifier]

    public init(key: KeyEquivalent, modifiers: [KeyModifier]) {
      self.key = key
      self.modifiers = modifiers
    }
  }

  public enum KeyboardShortcutKey: String, Codable, Sendable, CaseIterable, CodingKeyRepresentable {
    /// Add current selection / file to the existing chat's context.
    case addContextToCurrentChat
    /// Create a new chat thread and add current selection / file to its context.
    case addContextToNewChat
    /// Dismiss the chat UI.
    case dismissChat

    public var defaultShortcut: KeyboardShortcut {
      switch self {
      case .addContextToCurrentChat: KeyboardShortcut(key: "i", modifiers: [.command])
      case .addContextToNewChat: KeyboardShortcut(key: "i", modifiers: [.command, .shift])
      case .dismissChat: KeyboardShortcut(key: .escape, modifiers: [.command])
      }
    }
  }
}

extension Settings.KeyboardShortcuts {
  public subscript(withDefault key: Settings.KeyboardShortcutKey) -> Settings.KeyboardShortcut {
    self[key] ?? key.defaultShortcut
  }
}

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
  public static let enableAnalyticsAndCrashReporting = "enableAnalyticsAndCrashReporting"
  public static let enableNetworkProxy = "enableNetworkProxy"
  public static let showToolInputCopyButtonInRelease = "showToolInputCopyButtonInRelease"
  public static let defaultLogLevel = "defaultLogLevel"
}

// MARK: - KeyEquivalent + Codable

extension KeyEquivalent: Codable {
  public init(from decoder: any Decoder) throws {
    try self.init(Character(String(from: decoder)))
  }

  public func encode(to encoder: any Encoder) throws {
    try String(character).encode(to: encoder)
  }

}
