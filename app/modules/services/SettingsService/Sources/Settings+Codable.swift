// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LLMFoundation
import SettingsServiceInterface

// MARK: - Settings + Codable

extension Settings: Codable {

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    try self.init(
      pointReleaseXcodeExtensionToDebugApp: container
        .decodeIfPresent(Bool.self, forKey: "pointReleaseXcodeExtensionToDebugApp") ?? false,
      allowAnonymousAnalytics: container.decodeIfPresent(Bool.self, forKey: "allowAnonymousAnalytics") ?? true,
      automaticallyCheckForUpdates: container.decodeIfPresent(Bool.self, forKey: "automaticallyCheckForUpdates") ?? true,
      fileEditMode: container.decodeIfPresent(FileEditMode.self, forKey: "fileEditMode") ?? .directIO,
      automaticallyUpdateXcodeSettings: container.decodeIfPresent(Bool.self, forKey: "automaticallyUpdateXcodeSettings") ?? false,
      preferedProviders: container.decodeIfPresent([String: String].self, forKey: "preferedProviders")?
        .reduce(into: [LLMModel: LLMProvider]()) { acc, el in
          guard let model = LLMModel(rawValue: el.key), let provider = LLMProvider(rawValue: el.value) else { return }
          acc[model] = provider
        } ?? [:],
      llmProviderSettings: container
        .decodeIfPresent([String: LLMProviderSettings].self, forKey: "llmProviderSettings")?
        .reduce(into: [LLMProvider: LLMProviderSettings]()) { acc, el in
          guard let provider = LLMProvider(rawValue: el.key) else { return }
          acc[provider] = el.value
        } ?? [:],
      inactiveModels: container
        .decodeIfPresent([String].self, forKey: "inactiveModels")?
        .compactMap { modelName in LLMModel(rawValue: modelName) } ?? [],
      reasoningModels: container
        .decodeIfPresent([String: LLMReasoningSetting].self, forKey: "reasoningModels")?
        .reduce(into: [LLMModel: LLMReasoningSetting]()) { acc, el in
          guard let provider = LLMModel(rawValue: el.key) else { return }
          acc[provider] = el.value
        } ?? [:],
      customInstructions: container
        .decodeIfPresent(Settings.CustomInstructions.self, forKey: "customInstructions") ?? Settings.CustomInstructions(),
      toolPreferences: container
        .decodeIfPresent([Settings.ToolPreference].self, forKey: "toolPreferences") ?? [],
      keyboardShortcuts: container
        .decodeIfPresent(Settings.KeyboardShortcuts.self, forKey: "keyboardShortcuts") ?? Settings.KeyboardShortcuts())
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
