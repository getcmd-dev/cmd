// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import Foundation
import FoundationInterfaces
import LLMFoundation
import LoggingServiceInterface
import SettingsServiceInterface
import System

typealias ToolPreference = Settings.ToolPreference
typealias KeyboardShortcuts = Settings.KeyboardShortcuts

// MARK: - ExternalSettings

/// Settings that are exposed to the user. They are typically written to a known location to simplify edits by the user.
struct ExternalSettings: Sendable, Equatable {
  init(
    allowAnonymousAnalytics: Bool = true,
    automaticallyCheckForUpdates: Bool = true,
    automaticallyUpdateXcodeSettings: Bool = false,
    fileEditMode: FileEditMode = .directIO,
    preferedProviders: [String: AIProvider] = [:],
    llmProviderSettings: [AIProvider: AIProviderSettings] = [:],
    enabledModels: [AIModelID] = [],
    reasoningModels: [AIModelID: LLMReasoningSetting] = [:],
    chatModeConfigurations: [String: Settings.ChatModeConfiguration] = [:],
    toolPreferences: [ToolPreference] = [],
    keyboardShortcuts: KeyboardShortcuts = KeyboardShortcuts(),
    userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut] = [],
    mcpServers: [String: MCPServerConfiguration] = [:],
    codeCompletionProviderId: String? = nil,
    enableCodeCompletion: Bool = false)
  {
    self.allowAnonymousAnalytics = allowAnonymousAnalytics
    self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
    self.automaticallyUpdateXcodeSettings = automaticallyUpdateXcodeSettings
    self.fileEditMode = fileEditMode
    self.preferedProviders = preferedProviders.filter { llmProviderSettings[$0.value] != nil }
    self.llmProviderSettings = llmProviderSettings
    self.enabledModels = enabledModels
    self.reasoningModels = reasoningModels
    self.chatModeConfigurations = chatModeConfigurations
    self.toolPreferences = toolPreferences
    self.keyboardShortcuts = keyboardShortcuts
    self.userDefinedXcodeShortcuts = userDefinedXcodeShortcuts
    self.mcpServers = mcpServers
    self.codeCompletionProviderId = codeCompletionProviderId
    self.enableCodeCompletion = enableCodeCompletion
  }

  static let defaultSettings = ExternalSettings()

  let allowAnonymousAnalytics: Bool
  let automaticallyCheckForUpdates: Bool
  /// Whether to automatically update Xcode settings to configure `cmd` as an AI backend.
  let automaticallyUpdateXcodeSettings: Bool
  let fileEditMode: FileEditMode
  // LLM settings
  let preferedProviders: [String: AIProvider]
  var llmProviderSettings: [AIProvider: AIProviderSettings]
  let reasoningModels: [AIModelID: LLMReasoningSetting]

  let enabledModels: [AIModelID]
  let chatModeConfigurations: [String: Settings.ChatModeConfiguration]
  let toolPreferences: [ToolPreference]
  let keyboardShortcuts: KeyboardShortcuts
  let userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut]
  let mcpServers: [String: MCPServerConfiguration]
  let codeCompletionProviderId: String?
  let enableCodeCompletion: Bool
}

// MARK: - InternalSettings

struct InternalSettings: Sendable, Equatable {
  init(
    pointReleaseXcodeExtensionToDebugApp: Bool,
    knownToolReferenceIds: [String] = [],
    defaultLogLevel: LogLevel = .info,
    queueMessagesWhileStreaming: Bool = true)
  {
    self.pointReleaseXcodeExtensionToDebugApp = pointReleaseXcodeExtensionToDebugApp
    self.knownToolReferenceIds = knownToolReferenceIds
    self.defaultLogLevel = defaultLogLevel
    self.queueMessagesWhileStreaming = queueMessagesWhileStreaming
  }

  static let defaultSettings = InternalSettings(
    pointReleaseXcodeExtensionToDebugApp: false,
    knownToolReferenceIds: [],
    defaultLogLevel: .info,
    queueMessagesWhileStreaming: true)

  var pointReleaseXcodeExtensionToDebugApp: Bool
  /// Array of known tool reference IDs. This is internal state not exposed to users.
  var knownToolReferenceIds: [String]
  var defaultLogLevel: LogLevel
  var queueMessagesWhileStreaming: Bool
}

// MARK: - ExternalSettings + Codable

extension ExternalSettings: Codable {

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)

    let llmProviderSettings: [AIProvider: AIProviderSettings] = container
      .resilientlyDecodeIfPresent([String: AIProviderSettings].self, forKey: "llmProviderSettings")?
      .reduce(into: [AIProvider: AIProviderSettings]()) { acc, el in
        guard let provider = AIProvider(rawValue: el.key) else { return }
        acc[provider] = el.value
      } ?? Self.defaultSettings.llmProviderSettings

    self.init(
      allowAnonymousAnalytics: container.resilientlyDecodeIfPresent(Bool.self, forKey: "allowAnonymousAnalytics") ?? Self
        .defaultSettings.allowAnonymousAnalytics,
      automaticallyCheckForUpdates: container
        .resilientlyDecodeIfPresent(Bool.self, forKey: "automaticallyCheckForUpdates") ?? Self.defaultSettings
        .automaticallyCheckForUpdates,
      automaticallyUpdateXcodeSettings: container.resilientlyDecodeIfPresent(
        Bool.self,
        forKey: "automaticallyUpdateXcodeSettings") ?? Self.defaultSettings.automaticallyUpdateXcodeSettings,
      fileEditMode: container.resilientlyDecodeIfPresent(FileEditMode.self, forKey: "fileEditMode") ?? Self.defaultSettings
        .fileEditMode,
      preferedProviders: container.resilientlyDecodeIfPresent([String: String].self, forKey: "preferedProviders")?
        .reduce(into: [String: AIProvider]()) { acc, el in
          guard let provider = AIProvider(rawValue: el.value), llmProviderSettings[provider] != nil else { return }
          acc[el.key] = provider
        } ?? Self.defaultSettings.preferedProviders,
      llmProviderSettings: llmProviderSettings,
      enabledModels: container.resilientlyDecodeIfPresent([String].self, forKey: "enabledModels") ?? Self.defaultSettings
        .enabledModels,
      reasoningModels: container
        .resilientlyDecodeIfPresent([AIModelID: LLMReasoningSetting].self, forKey: "reasoningModels") ?? Self.defaultSettings
        .reasoningModels,
      chatModeConfigurations: container
        .resilientlyDecodeIfPresent([String: Settings.ChatModeConfiguration].self, forKey: "chatModeConfigurations") ?? Self
        .defaultSettings.chatModeConfigurations,
      toolPreferences: container
        .resilientlyDecodeIfPresent([Settings.ToolPreference].self, forKey: "toolPreferences") ?? Self.defaultSettings
        .toolPreferences,
      keyboardShortcuts: container
        .resilientlyDecodeIfPresent(Settings.KeyboardShortcuts.self, forKey: "keyboardShortcuts") ?? Self.defaultSettings
        .keyboardShortcuts,
      userDefinedXcodeShortcuts: container
        .resilientlyDecodeIfPresent([UserDefinedXcodeShortcut].self, forKey: "userDefinedXcodeShortcuts") ?? Self.defaultSettings
        .userDefinedXcodeShortcuts,
      mcpServers: container.resilientlyDecodeIfPresent(MCPServerConfigurations.self, forKey: "mcpServers")?.configurations ?? [:],
      codeCompletionProviderId: container.resilientlyDecodeIfPresent(String.self, forKey: "codeCompletionProviderId") ?? nil,
      enableCodeCompletion: container.resilientlyDecodeIfPresent(Bool.self, forKey: "enableCodeCompletion") ?? Self
        .defaultSettings.enableCodeCompletion)
  }

  func encode(to encoder: any Encoder) throws {
    let doNotEncodeDefaultValues = (encoder.userInfo[.doNotEncodeDefaultValues] as? Bool) ?? false
    let encodeAllValues = !doNotEncodeDefaultValues
    var container = encoder.container(keyedBy: String.self)
    if encodeAllValues || allowAnonymousAnalytics != Self.defaultSettings.allowAnonymousAnalytics {
      try container.encode(allowAnonymousAnalytics, forKey: "allowAnonymousAnalytics")
    }
    if encodeAllValues || automaticallyCheckForUpdates != Self.defaultSettings.automaticallyCheckForUpdates {
      try container.encode(automaticallyCheckForUpdates, forKey: "automaticallyCheckForUpdates")
    }
    if encodeAllValues || fileEditMode != Self.defaultSettings.fileEditMode {
      try container.encode(fileEditMode, forKey: "fileEditMode")
    }
    if encodeAllValues || automaticallyUpdateXcodeSettings != Self.defaultSettings.automaticallyUpdateXcodeSettings {
      try container.encode(automaticallyUpdateXcodeSettings, forKey: "automaticallyUpdateXcodeSettings")
    }
    if encodeAllValues || preferedProviders != Self.defaultSettings.preferedProviders {
      try container.encode(preferedProviders, forKey: "preferedProviders")
    }
    if encodeAllValues || llmProviderSettings != Self.defaultSettings.llmProviderSettings {
      try container.encode(llmProviderSettings.reduce(into: [String: AIProviderSettings]()) { acc, el in
        acc[el.key.rawValue] = el.value
      }, forKey: "llmProviderSettings")
    }
    if encodeAllValues || enabledModels != Self.defaultSettings.enabledModels {
      try container.encode(enabledModels, forKey: "enabledModels")
    }
    if encodeAllValues || reasoningModels != Self.defaultSettings.reasoningModels {
      try container.encode(reasoningModels, forKey: "reasoningModels")
    }
    // Only encode chat mode configurations that differ from defaults
    if encodeAllValues || chatModeConfigurations != Self.defaultSettings.chatModeConfigurations {
      let nonDefaultConfigs = chatModeConfigurations.filter { $1 != Settings.ChatModeConfiguration.defaultValue }
      // Only encode if there are non-default configs OR if we're encoding all values AND configs exist
      if !nonDefaultConfigs.isEmpty {
        try container.encode(nonDefaultConfigs, forKey: "chatModeConfigurations")
      } else if encodeAllValues, !chatModeConfigurations.isEmpty {
        try container.encode(chatModeConfigurations, forKey: "chatModeConfigurations")
      }
    }
    if encodeAllValues || toolPreferences != Self.defaultSettings.toolPreferences {
      try container.encode(toolPreferences, forKey: "toolPreferences")
    }
    if encodeAllValues || keyboardShortcuts != Self.defaultSettings.keyboardShortcuts {
      try container.encode(keyboardShortcuts, forKey: "keyboardShortcuts")
    }
    if encodeAllValues || userDefinedXcodeShortcuts != Self.defaultSettings.userDefinedXcodeShortcuts {
      try container.encode(userDefinedXcodeShortcuts, forKey: "userDefinedXcodeShortcuts")
    }
    if encodeAllValues || mcpServers != Self.defaultSettings.mcpServers {
      try container.encode(MCPServerConfigurations(configurations: mcpServers), forKey: "mcpServers")
    }
    if encodeAllValues || codeCompletionProviderId != Self.defaultSettings.codeCompletionProviderId {
      try container.encode(codeCompletionProviderId, forKey: "codeCompletionProviderId")
    }
    if encodeAllValues || enableCodeCompletion != Self.defaultSettings.enableCodeCompletion {
      try container.encode(enableCodeCompletion, forKey: "enableCodeCompletion")
    }
  }
}

// MARK: - InternalSettings + Codable

extension InternalSettings: Codable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    self.init(
      pointReleaseXcodeExtensionToDebugApp: container.resilientlyDecodeIfPresent(
        Bool.self,
        forKey: "pointReleaseXcodeExtensionToDebugApp") ?? false,
      knownToolReferenceIds: container.resilientlyDecodeIfPresent(
        [String].self,
        forKey: "knownToolReferenceIds") ?? Self.defaultSettings.knownToolReferenceIds,
      defaultLogLevel: container.resilientlyDecodeIfPresent(
        LogLevel.self,
        forKey: "defaultLogLevel") ?? Self.defaultSettings.defaultLogLevel,
      queueMessagesWhileStreaming: container.resilientlyDecodeIfPresent(
        Bool.self,
        forKey: "queueMessagesWhileStreaming") ?? Self.defaultSettings.queueMessagesWhileStreaming)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    // Always encode fields, except for queueMessagesWhileStreaming which we only encode if non-default
    try container.encode(pointReleaseXcodeExtensionToDebugApp, forKey: "pointReleaseXcodeExtensionToDebugApp")
    try container.encode(knownToolReferenceIds, forKey: "knownToolReferenceIds")
    try container.encode(defaultLogLevel, forKey: "defaultLogLevel")
    // Only encode queueMessagesWhileStreaming if it differs from the default
    if queueMessagesWhileStreaming != Self.defaultSettings.queueMessagesWhileStreaming {
      try container.encode(queueMessagesWhileStreaming, forKey: "queueMessagesWhileStreaming")
    }
  }
}

extension Encodable {

  // TODO: add merge strategy?
  /// Write the object to the desired location.
  /// Only write entries that either have a non-default value, or already that exist in the file.
  /// If a file already exist at the target location, all existing keys that are not key of the new object are preserved.
  func writeNonDefaultValues(to url: URL, fileManager: FileManagerI) throws {
    try fileManager.createDirectories(requiredForFileAt: url)

    if !fileManager.fileExists(atPath: url.path) {
      let encoder = JSONEncoder()
      encoder.userInfo[.doNotEncodeDefaultValues] = true
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(self)
      try fileManager.write(data: data, to: url)
      return
    }
    // If a file exist:
    // - for overlapping keys, we replace existing keys with the new values
    // - for non existing keys, we only write non default-values
    // - for existing keys that are not overlapping with the new object, we preserve them
    // This allows for sparse settings that are user facing, while always
    // writting values for keys that have been modified by the user once.
    let fullyEncodedData = try JSONEncoder().encode(self)
    let fullyEncoded = try JSONSerialization.jsonObject(with: fullyEncodedData) as? [String: Any]
    let partialEncoder = JSONEncoder()
    partialEncoder.userInfo[.doNotEncodeDefaultValues] = true
    let partiallyEncodedData = try partialEncoder.encode(self)
    let partiallyEncoded = try JSONSerialization.jsonObject(with: partiallyEncodedData) as? [String: Any]
    let existing = try? {
      let data = try fileManager.read(dataFrom: url)
      return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }()
    var merged = existing ?? [:]
    for (key, value) in partiallyEncoded ?? [:] {
      merged[key] = value
    }
    for (key, value) in fullyEncoded ?? [:] {
      if existing?.keys.contains(key) == true {
        merged[key] = value
      }
    }
    let mergedData = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
    try fileManager.write(data: mergedData, to: url)
  }
}

extension Settings {
  init(externalSettings: ExternalSettings, internalSettings: InternalSettings) {
    self.init(
      pointReleaseXcodeExtensionToDebugApp: internalSettings.pointReleaseXcodeExtensionToDebugApp,
      allowAnonymousAnalytics: externalSettings.allowAnonymousAnalytics,
      automaticallyCheckForUpdates: externalSettings.automaticallyCheckForUpdates,
      automaticallyUpdateXcodeSettings: externalSettings.automaticallyUpdateXcodeSettings,
      fileEditMode: externalSettings.fileEditMode,
      preferedProviders: externalSettings.preferedProviders,
      llmProviderSettings: externalSettings.llmProviderSettings,
      enabledModels: externalSettings.enabledModels,
      reasoningModels: externalSettings.reasoningModels,
      chatModeConfigurations: externalSettings.chatModeConfigurations,
      knownToolReferenceIds: internalSettings.knownToolReferenceIds,
      toolPreferences: externalSettings.toolPreferences,
      keyboardShortcuts: externalSettings.keyboardShortcuts,
      userDefinedXcodeShortcuts: externalSettings.userDefinedXcodeShortcuts,
      mcpServers: externalSettings.mcpServers,
      defaultLogLevel: internalSettings.defaultLogLevel,
      codeCompletionProviderId: externalSettings.codeCompletionProviderId,
      enableCodeCompletion: externalSettings.enableCodeCompletion,
      queueMessagesWhileStreaming: internalSettings.queueMessagesWhileStreaming)
  }

  var externalSettings: ExternalSettings {
    .init(
      allowAnonymousAnalytics: allowAnonymousAnalytics,
      automaticallyCheckForUpdates: automaticallyCheckForUpdates,
      automaticallyUpdateXcodeSettings: automaticallyUpdateXcodeSettings,
      fileEditMode: fileEditMode,
      preferedProviders: preferedProviders,
      llmProviderSettings: llmProviderSettings,
      enabledModels: enabledModels,
      reasoningModels: reasoningModels,
      chatModeConfigurations: chatModeConfigurations,
      toolPreferences: toolPreferences,
      keyboardShortcuts: keyboardShortcuts,
      userDefinedXcodeShortcuts: userDefinedXcodeShortcuts,
      mcpServers: mcpServers,
      codeCompletionProviderId: codeCompletionProviderId,
      enableCodeCompletion: enableCodeCompletion)
  }

  func internalSettings() -> InternalSettings {
    .init(
      pointReleaseXcodeExtensionToDebugApp: pointReleaseXcodeExtensionToDebugApp,
      knownToolReferenceIds: knownToolReferenceIds,
      defaultLogLevel: defaultLogLevel,
      queueMessagesWhileStreaming: queueMessagesWhileStreaming)
  }
}

extension CodingUserInfoKey {
  /// Whether to encode values for all keys, or only for those that have a non default value.
  static let doNotEncodeDefaultValues = CodingUserInfoKey(rawValue: "doNotEncodeDefaultValues")!
}

extension Settings.ChatModeConfiguration {
  static var defaultValue: Settings.ChatModeConfiguration { .init() }
}
