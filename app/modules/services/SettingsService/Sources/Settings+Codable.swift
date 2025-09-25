// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LLMFoundation
import LoggingServiceInterface
import SettingsServiceInterface

// MARK: - Settings + Codable

/// Settings is kept Decodable to maintain backward compatibility with older versions of the app where settings were serialized in different location / formats.
extension Settings: Codable {

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    self.init(
      pointReleaseXcodeExtensionToDebugApp: container
        .resilientlyDecodeIfPresent(Bool.self, forKey: "pointReleaseXcodeExtensionToDebugApp") ?? false,
      allowAnonymousAnalytics: container.resilientlyDecodeIfPresent(Bool.self, forKey: "allowAnonymousAnalytics") ?? true,
      automaticallyCheckForUpdates: container
        .resilientlyDecodeIfPresent(Bool.self, forKey: "automaticallyCheckForUpdates") ?? true,
      automaticallyUpdateXcodeSettings: container.resilientlyDecodeIfPresent(
        Bool.self,
        forKey: "automaticallyUpdateXcodeSettings") ?? false,
      fileEditMode: container.resilientlyDecodeIfPresent(FileEditMode.self, forKey: "fileEditMode") ?? .directIO,
      preferedProviders: container.resilientlyDecodeIfPresent([String: String].self, forKey: "preferedProviders")?
        .reduce(into: [LLMModel: LLMProvider]()) { acc, el in
          guard let model = LLMModel(rawValue: el.key), let provider = LLMProvider(rawValue: el.value) else { return }
          acc[model] = provider
        } ?? [:],
      llmProviderSettings: container
        .resilientlyDecodeIfPresent([String: LLMProviderSettings].self, forKey: "llmProviderSettings")?
        .reduce(into: [LLMProvider: LLMProviderSettings]()) { acc, el in
          guard let provider = LLMProvider(rawValue: el.key) else { return }
          acc[provider] = el.value
        } ?? [:],
      inactiveModels: container
        .resilientlyDecodeIfPresent([String].self, forKey: "inactiveModels")?
        .compactMap { modelName in LLMModel(rawValue: modelName) } ?? [],
      reasoningModels: container
        .resilientlyDecodeIfPresent([String: LLMReasoningSetting].self, forKey: "reasoningModels")?
        .reduce(into: [LLMModel: LLMReasoningSetting]()) { acc, el in
          guard let provider = LLMModel(rawValue: el.key) else { return }
          acc[provider] = el.value
        } ?? [:],
      customInstructions: container
        .resilientlyDecodeIfPresent(Settings.CustomInstructions.self, forKey: "customInstructions") ?? Settings
        .CustomInstructions(),
      toolPreferences: container
        .resilientlyDecodeIfPresent([Settings.ToolPreference].self, forKey: "toolPreferences") ?? [],
      keyboardShortcuts: container
        .resilientlyDecodeIfPresent(Settings.KeyboardShortcuts.self, forKey: "keyboardShortcuts") ?? Settings.KeyboardShortcuts(),
      userDefinedXcodeShortcuts: container
        .resilientlyDecodeIfPresent([UserDefinedXcodeShortcut].self, forKey: "userDefinedXcodeShortcuts") ?? [],
      mcpServers: container.resilientlyDecodeIfPresent(MCPServerConfigurations.self, forKey: "mcpServers")?.configurations ?? [:])
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    try container.encode(pointReleaseXcodeExtensionToDebugApp, forKey: "pointReleaseXcodeExtensionToDebugApp")
    try container.encode(allowAnonymousAnalytics, forKey: "allowAnonymousAnalytics")
    try container.encode(automaticallyCheckForUpdates, forKey: "automaticallyCheckForUpdates")
    try container.encode(fileEditMode, forKey: "fileEditMode")
    try container.encode(automaticallyUpdateXcodeSettings, forKey: "automaticallyUpdateXcodeSettings")
    try container.encode(preferedProviders.reduce(into: [String: String]()) { acc, el in
      acc[el.key.rawValue] = el.value.rawValue
    }, forKey: "preferedProviders")
    try container.encode(llmProviderSettings.reduce(into: [String: LLMProviderSettings]()) { acc, el in
      acc[el.key.rawValue] = el.value
    }, forKey: "llmProviderSettings")
    try container.encode(inactiveModels.map(\.rawValue), forKey: "inactiveModels")
    try container.encode(reasoningModels.reduce(into: [String: LLMReasoningSetting]()) { acc, el in
      acc[el.key.rawValue] = el.value
    }, forKey: "reasoningModels")
    try container.encode(customInstructions, forKey: "customInstructions")
    try container.encode(toolPreferences, forKey: "toolPreferences")
    try container.encode(keyboardShortcuts, forKey: "keyboardShortcuts")
    try container.encode(userDefinedXcodeShortcuts, forKey: "userDefinedXcodeShortcuts")
    try container.encode(MCPServerConfigurations(configurations: mcpServers), forKey: "mcpServers")
  }
}

// MARK: - LLMReasoningSetting + Codable

extension LLMReasoningSetting: Codable {

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    try self.init(
      isEnabled: container.decodeIfPresent(Bool.self, forKey: "isEnabled") ?? false)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    try container.encode(isEnabled, forKey: "isEnabled")
  }
}

extension KeyedDecodingContainer where K == String {
  /// Decoding the desired key, returning nil when the decoding fails.
  /// This allows for an object to not fail entirely when one property could not be decoded, which is desirable for settings.
  /// For instance this prevents one buggy format change from destroying all user settings.
  public func resilientlyDecodeIfPresent<T: Decodable>(_: T.Type, forKey key: KeyedDecodingContainer<K>.Key) -> T? {
    do {
      return try decodeIfPresent(T.self, forKey: key)
    } catch {
      defaultLogger.error("Failed to decode \(T.self) for key \(key) at \(codingPath): \(error)")
      return nil
    }
  }
}
