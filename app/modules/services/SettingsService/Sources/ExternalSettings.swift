// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FoundationInterfaces
import LLMFoundation
import SettingsServiceInterface
import System

typealias CustomInstructions = Settings.CustomInstructions
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
    preferedProviders: [LLMModel: LLMProvider] = [:],
    llmProviderSettings: [LLMProvider: LLMProviderSettings] = [:],
    inactiveModels: [LLMModel] = [],
    reasoningModels: [LLMModel: LLMReasoningSetting] = [:],
    customInstructions: CustomInstructions = CustomInstructions(),
    toolPreferences: [ToolPreference] = [],
    keyboardShortcuts: KeyboardShortcuts = KeyboardShortcuts(),
    userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut] = [])
  {
    self.allowAnonymousAnalytics = allowAnonymousAnalytics
    self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
    self.automaticallyUpdateXcodeSettings = automaticallyUpdateXcodeSettings
    self.fileEditMode = fileEditMode
    self.preferedProviders = preferedProviders
    self.llmProviderSettings = llmProviderSettings
    self.inactiveModels = inactiveModels
    self.reasoningModels = reasoningModels
    self.customInstructions = customInstructions
    self.toolPreferences = toolPreferences
    self.keyboardShortcuts = keyboardShortcuts
    self.userDefinedXcodeShortcuts = userDefinedXcodeShortcuts
  }

  static let defaultSettings = ExternalSettings()

  var allowAnonymousAnalytics: Bool
  var automaticallyCheckForUpdates: Bool
  /// Whether to automatically update Xcode settings to configure `cmd` as an AI backend.
  var automaticallyUpdateXcodeSettings: Bool
  var fileEditMode: FileEditMode
  // LLM settings
  var preferedProviders: [LLMModel: LLMProvider]
  var llmProviderSettings: [LLMProvider: LLMProviderSettings]
  var reasoningModels: [LLMModel: LLMReasoningSetting]

  var inactiveModels: [LLMModel]
  var customInstructions: CustomInstructions
  var toolPreferences: [ToolPreference]
  var keyboardShortcuts: KeyboardShortcuts
  var userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut]

}

// MARK: - InternalSettings

struct InternalSettings: Sendable, Equatable {
  static let defaultSettings = InternalSettings(pointReleaseXcodeExtensionToDebugApp: false)
  init(pointReleaseXcodeExtensionToDebugApp: Bool) {
    self.pointReleaseXcodeExtensionToDebugApp = pointReleaseXcodeExtensionToDebugApp
  }

  var pointReleaseXcodeExtensionToDebugApp: Bool
}

// MARK: - ExternalSettings + Codable

extension ExternalSettings: Codable {

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
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
        .reduce(into: [LLMModel: LLMProvider]()) { acc, el in
          guard let model = LLMModel(rawValue: el.key), let provider = LLMProvider(rawValue: el.value) else { return }
          acc[model] = provider
        } ?? Self.defaultSettings.preferedProviders,
      llmProviderSettings: container
        .resilientlyDecodeIfPresent([String: LLMProviderSettings].self, forKey: "llmProviderSettings")?
        .reduce(into: [LLMProvider: LLMProviderSettings]()) { acc, el in
          guard let provider = LLMProvider(rawValue: el.key) else { return }
          acc[provider] = el.value
        } ?? Self.defaultSettings.llmProviderSettings,
      inactiveModels: container
        .resilientlyDecodeIfPresent([String].self, forKey: "inactiveModels")?
        .compactMap { modelName in LLMModel(rawValue: modelName) } ?? Self.defaultSettings.inactiveModels,
      reasoningModels: container
        .resilientlyDecodeIfPresent([String: LLMReasoningSetting].self, forKey: "reasoningModels")?
        .reduce(into: [LLMModel: LLMReasoningSetting]()) { acc, el in
          guard let provider = LLMModel(rawValue: el.key) else { return }
          acc[provider] = el.value
        } ?? Self.defaultSettings.reasoningModels,
      customInstructions: container
        .resilientlyDecodeIfPresent(Settings.CustomInstructions.self, forKey: "customInstructions") ?? Self.defaultSettings
        .customInstructions,
      toolPreferences: container
        .resilientlyDecodeIfPresent([Settings.ToolPreference].self, forKey: "toolPreferences") ?? Self.defaultSettings
        .toolPreferences,
      keyboardShortcuts: container
        .resilientlyDecodeIfPresent(Settings.KeyboardShortcuts.self, forKey: "keyboardShortcuts") ?? Self.defaultSettings
        .keyboardShortcuts,
      userDefinedXcodeShortcuts: container
        .resilientlyDecodeIfPresent([UserDefinedXcodeShortcut].self, forKey: "userDefinedXcodeShortcuts") ?? Self.defaultSettings
        .userDefinedXcodeShortcuts)
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
      try container.encode(preferedProviders.reduce(into: [String: String]()) { acc, el in
        acc[el.key.rawValue] = el.value.rawValue
      }, forKey: "preferedProviders")
    }
    if encodeAllValues || llmProviderSettings != Self.defaultSettings.llmProviderSettings {
      try container.encode(llmProviderSettings.reduce(into: [String: LLMProviderSettings]()) { acc, el in
        acc[el.key.rawValue] = el.value
      }, forKey: "llmProviderSettings")
    }
    if encodeAllValues || inactiveModels != Self.defaultSettings.inactiveModels {
      try container.encode(inactiveModels.map(\.rawValue), forKey: "inactiveModels")
    }
    if encodeAllValues || reasoningModels != Self.defaultSettings.reasoningModels {
      try container.encode(reasoningModels.reduce(into: [String: LLMReasoningSetting]()) { acc, el in
        acc[el.key.rawValue] = el.value
      }, forKey: "reasoningModels")
    }
    if encodeAllValues || customInstructions != Self.defaultSettings.customInstructions {
      try container.encode(customInstructions, forKey: "customInstructions")
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
  }
}

// MARK: - InternalSettings + Codable

extension InternalSettings: Codable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    self.init(
      pointReleaseXcodeExtensionToDebugApp: container.resilientlyDecodeIfPresent(
        Bool.self,
        forKey: "pointReleaseXcodeExtensionToDebugApp") ?? false)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    try container.encode(pointReleaseXcodeExtensionToDebugApp, forKey: "pointReleaseXcodeExtensionToDebugApp")
  }
}

extension Encodable {

  // TODO: add merge strategy?
  /// Write the object to the desired location.
  /// Only write entries that either have a non-default value, or already that exist in the file.
  /// If a file already exist at the target location, all existing keys that are not key of the new object are preserved.
  func writeNonDefaultValues(to path: FilePath, fileManager: FileManagerI) throws {
    let fileUrl = URL(filePath: path.string)
    try fileManager.createDirectories(requiredForFileAt: fileUrl)

    if !fileManager.fileExists(atPath: path.string) {
      let encoder = JSONEncoder()
      encoder.userInfo[.doNotEncodeDefaultValues] = true
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(self)
      try fileManager.write(data: data, to: fileUrl)
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
      let data = try fileManager.read(dataFrom: fileUrl)
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
    try fileManager.write(data: mergedData, to: fileUrl)
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
      inactiveModels: externalSettings.inactiveModels,
      reasoningModels: externalSettings.reasoningModels,
      customInstructions: externalSettings.customInstructions,
      toolPreferences: externalSettings.toolPreferences,
      keyboardShortcuts: externalSettings.keyboardShortcuts,
      userDefinedXcodeShortcuts: externalSettings.userDefinedXcodeShortcuts)
  }

  var externalSettings: ExternalSettings {
    .init(
      allowAnonymousAnalytics: allowAnonymousAnalytics,
      automaticallyCheckForUpdates: automaticallyCheckForUpdates,
      automaticallyUpdateXcodeSettings: automaticallyUpdateXcodeSettings,
      fileEditMode: fileEditMode,
      preferedProviders: preferedProviders,
      llmProviderSettings: llmProviderSettings,
      inactiveModels: inactiveModels,
      reasoningModels: reasoningModels,
      customInstructions: customInstructions,
      toolPreferences: toolPreferences,
      keyboardShortcuts: keyboardShortcuts,
      userDefinedXcodeShortcuts: userDefinedXcodeShortcuts)
  }

  var internalSettings: InternalSettings {
    .init(pointReleaseXcodeExtensionToDebugApp: pointReleaseXcodeExtensionToDebugApp)
  }
}

extension CodingUserInfoKey {
  /// Whether to encode values for all keys, or only for those that have a non default value.
  static let doNotEncodeDefaultValues = CodingUserInfoKey(rawValue: "doNotEncodeDefaultValues")!
}
