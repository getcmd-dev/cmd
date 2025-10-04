// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FoundationInterfaces
import LLMFoundation
import SettingsServiceInterface
import SharedValuesFoundation
import Testing
@testable import SettingsService

import SwiftTesting

@Suite("Settings Migration Tests")
struct SettingsMigrationTests {

  @Test("Happy path migration from legacy UserDefaults to new storage format")
  @MainActor
  func test_happyPathMigration() async throws {
    // given
    let fileManager = MockFileManager()
    let sharedUserDefaults = MockUserDefaults()
    let settingsFileLocation = fileManager.homeDirectoryForCurrentUser.appending(path: ".cmd/settings.json")

    let didRemoveOldEntryFromUserDefaults = expectation(description: "Old entry removed from UserDefaults")
    sharedUserDefaults.onRemoveObjectForKey = { key in
      #expect(key == "appWideSettings")
      didRemoveOldEntryFromUserDefaults.fulfill()
    }

    // Setup legacy storage format with settings in UserDefaults
    let legacySettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      automaticallyCheckForUpdates: false,
      automaticallyUpdateXcodeSettings: true,
      fileEditMode: .xcodeExtension,
      preferedProviders: .init([.claudeHaiku_3_5: .anthropic, .gpt: .openAI]),
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "ANTHROPIC_API_KEY", // Legacy keychain reference
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "OPENAI_API_KEY", // Legacy keychain reference
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ])

    // Store legacy settings in UserDefaults with old format
    let legacyData = try JSONEncoder().encode(legacySettings)
    sharedUserDefaults.set(legacyData, forKey: DefaultSettingsService.Keys.appWideSettings)

    // Store API keys in legacy keychain format (without "cmd-keychain-key-" prefix)
    sharedUserDefaults.securelySave("test-anthropic-key", forKey: "ANTHROPIC_API_KEY")
    sharedUserDefaults.securelySave("test-openai-key", forKey: "OPENAI_API_KEY")

    // Store pointReleaseXcodeExtensionToDebugApp separately in UserDefaults
    sharedUserDefaults.set(true, forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)

    // when
    let sut = DefaultSettingsService(
      fileManager: fileManager,
      settingsFileLocation: settingsFileLocation,
      sharedUserDefaults: sharedUserDefaults,
      releaseSharedUserDefaults: nil)

    // Give migration task time to complete
    try await fulfillment(of: didRemoveOldEntryFromUserDefaults)

    // then
    // Verify settings are correctly loaded and migrated
    #expect(sut.value(for: \.allowAnonymousAnalytics) == false)
    #expect(sut.value(for: \.automaticallyCheckForUpdates) == false)
    #expect(sut.value(for: \.fileEditMode) == .xcodeExtension)
    #expect(sut.value(for: \.automaticallyUpdateXcodeSettings) == true)
    #expect(sut.value(for: \.pointReleaseXcodeExtensionToDebugApp) == true)

    // Verify API keys are accessible with actual values (not keychain references)
    let anthropicSettings = sut.value(for: \.llmProviderSettings)[.anthropic]
    #expect(anthropicSettings?.apiKey == "test-anthropic-key")
    #expect(anthropicSettings?.createdOrder == 1)

    let openAISettings = sut.value(for: \.llmProviderSettings)[.openAI]
    #expect(openAISettings?.apiKey == "test-openai-key")
    #expect(openAISettings?.createdOrder == 2)

    // Verify preferred providers
    #expect(sut.value(for: \.preferedProviders)[.claudeHaiku_3_5] == .anthropic)
    #expect(sut.value(for: \.preferedProviders)[.gpt] == .openAI)

    // Verify migration to new storage format occurred

    // 1. Legacy UserDefaults key should be removed
    #expect(sharedUserDefaults.dumpStorage()[DefaultSettingsService.Keys.appWideSettings] == nil)

    // 2. Internal settings should be stored in UserDefaults with new key
    let internalData = try #require(sharedUserDefaults.dumpStorage()[DefaultSettingsService.Keys.internalSettings] as? Data)
    let internalSettings = try JSONDecoder().decode(InternalSettings.self, from: internalData)
    #expect(internalSettings.pointReleaseXcodeExtensionToDebugApp == true)

    // 3. External settings should be written to disk file
    #expect(fileManager.fileExists(atPath: settingsFileLocation.path))
    let externalData = try fileManager.read(dataFrom: settingsFileLocation)
    let externalSettings = try JSONDecoder().decode(ExternalSettings.self, from: externalData)
    #expect(externalSettings.allowAnonymousAnalytics == false)
    #expect(externalSettings.automaticallyCheckForUpdates == false)
    #expect(externalSettings.fileEditMode == .xcodeExtension)
    #expect(externalSettings.automaticallyUpdateXcodeSettings == true)

    // 4. API keys should be migrated to new keychain format with "cmd-keychain-key-" prefix
    let secureStorage = sharedUserDefaults.dumpSecureStorage()
    #expect(secureStorage["cmd-keychain-key-ANTHROPIC_API_KEY"] == "test-anthropic-key")
    #expect(secureStorage["cmd-keychain-key-OPENAI_API_KEY"] == "test-openai-key")

    // 5. Legacy keychain keys should still exist (migration doesn't remove them)
    #expect(secureStorage["ANTHROPIC_API_KEY"] == "test-anthropic-key")
    #expect(secureStorage["OPENAI_API_KEY"] == "test-openai-key")

    // 6. External settings file should reference new keychain keys
    #expect(externalSettings.llmProviderSettings[.anthropic]?.apiKey == "cmd-keychain-key-ANTHROPIC_API_KEY")
    #expect(externalSettings.llmProviderSettings[.openAI]?.apiKey == "cmd-keychain-key-OPENAI_API_KEY")

    // 7. Verify the pointReleaseXcodeExtensionToDebugApp is still in shared location
    #expect(sharedUserDefaults.bool(forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp) == true)
  }
}
