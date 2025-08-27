// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import LLMFoundation
import SettingsServiceInterface
import SharedValuesFoundation
import SwiftTesting
import Testing
@testable import SettingsService

// MARK: - DefaultSettingsServiceTests

struct DefaultSettingsServiceTests {

  @Test("Initializes with default values")
  @MainActor
  func test_initialization() {
    // Setup
    let sharedUserDefaults = MockUserDefaults()

    // Test
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    // Verify
    #expect(service.value(for: \.pointReleaseXcodeExtensionToDebugApp) == false)
    #expect(service.value(for: \.allowAnonymousAnalytics) == true)
    #expect(service.value(for: \.llmProviderSettings[.anthropic]) == nil)
    #expect(service.value(for: \.llmProviderSettings[.openAI]) == nil)
  }

  @Test("API keys are correctly mapped to keychain keys")
  @MainActor
  func test_apiKeyKeychainMapping() async throws {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    // Test individual provider key mapping
    let groqSettings = LLMProviderSettings(
      apiKey: "test-groq-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 1)
    let geminiSettings = LLMProviderSettings(
      apiKey: "test-gemini-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 2)

    var newSettings = service.value(for: \.llmProviderSettings)
    newSettings[.groq] = groqSettings
    newSettings[.gemini] = geminiSettings
    service.update(setting: \.llmProviderSettings, to: newSettings)

    // Verify the new providers (Groq and Gemini) are handled correctly
    #expect(service.value(for: \.llmProviderSettings[.groq]?.apiKey) == "test-groq-key")
    #expect(service.value(for: \.llmProviderSettings[.gemini]?.apiKey) == "test-gemini-key")

    // Wait for async storage
    let exp = expectation(description: "Storage completed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      exp.fulfill()
    }
    try await fulfillment(of: exp)

    // Verify secure storage has the correct keychain keys
    let secureStorage = sharedUserDefaults.dumpSecureStorage()
    #expect(secureStorage["GROQ_API_KEY"] == "test-groq-key")
    #expect(secureStorage["GEMINI_API_KEY"] == "test-gemini-key")
  }

  @Test("Updates and retrieves values")
  @MainActor
  func test_updateAndRetrieveValues() {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    // Test updating values
    service.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: true)

    let anthropicSettings = LLMProviderSettings(
      apiKey: "test-key",
      baseUrl: "https://api.anthropic.com/test",
      executable: nil,
      createdOrder: 1)
    var newSettings = service.value(for: \.llmProviderSettings)
    newSettings[.anthropic] = anthropicSettings
    service.update(setting: \.llmProviderSettings, to: newSettings)

    // Verify
    #expect(service.value(for: \.pointReleaseXcodeExtensionToDebugApp) == true)
    #expect(service.value(for: \.llmProviderSettings[.anthropic]?.apiKey) == "test-key")
    #expect(service.value(for: \.llmProviderSettings[.anthropic]?.baseUrl) == "https://api.anthropic.com/test")
  }

  @Test("Resets individual settings")
  @MainActor
  func test_resetIndividualSettings() {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    // Set initial values
    service.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: true)
    let anthropicSettings = LLMProviderSettings(
      apiKey: "test-key",
      baseUrl: "https://api.anthropic.com/test",
      executable: nil,
      createdOrder: 1)

    var newSettings = service.value(for: \.llmProviderSettings)
    newSettings[.anthropic] = anthropicSettings
    service.update(setting: \.llmProviderSettings, to: newSettings)

    // Reset individual setting
    service.resetToDefault(setting: \.pointReleaseXcodeExtensionToDebugApp)

    // Verify
    #expect(service.value(for: \.pointReleaseXcodeExtensionToDebugApp) == false)
    #expect(service.value(for: \.llmProviderSettings[.anthropic]?.apiKey) == "test-key")
  }

  @Test("Resets all settings")
  @MainActor
  func test_resetAllSettings() {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    // Set initial values
    service.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: true)
    let anthropicSettings = LLMProviderSettings(
      apiKey: "test-key",
      baseUrl: "https://api.anthropic.com/test",
      executable: nil,
      createdOrder: 1)
    let openAISettings = LLMProviderSettings(
      apiKey: "openai-key",
      baseUrl: "https://api.openai.com/test",
      executable: nil,
      createdOrder: 2)

    var newSettings = service.value(for: \.llmProviderSettings)
    newSettings[.anthropic] = anthropicSettings
    newSettings[.openAI] = openAISettings
    service.update(setting: \.llmProviderSettings, to: newSettings)

    // Reset all settings
    service.resetAllToDefault()

    // Verify
    #expect(service.value(for: \.pointReleaseXcodeExtensionToDebugApp) == false)
    #expect(service.value(for: \.allowAnonymousAnalytics) == true)
    #expect(service.value(for: \.llmProviderSettings[.anthropic]) == nil)
    #expect(service.value(for: \.llmProviderSettings[.openAI]) == nil)
  }

  @Test("Live values update when settings change")
  @MainActor
  func test_liveValuesUpdate() async throws {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    // Test live values
    var cancellables = Set<AnyCancellable>()
    var receivedValues: [Bool] = []
    let valuesReceived = expectation(description: "Values received")

    service.liveValue(for: \.pointReleaseXcodeExtensionToDebugApp)
      .sink { value in
        receivedValues.append(value)
        if receivedValues.count == 2 {
          valuesReceived.fulfill()
        }
      }
      .store(in: &cancellables)

    // Initial value should be received
    #expect(receivedValues.count == 1)
    #expect(receivedValues.first == false)

    // Update value
    service.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: true)

    try await fulfillment(of: [valuesReceived])
    #expect(receivedValues == [false, true])
  }

  @Test("Live values update when settings change on disk")
  @MainActor
  func test_liveValuesUpdateFromDiskChange() async throws {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    // Test live values
    var cancellables = Set<AnyCancellable>()
    var receivedValues: [Bool] = []
    let valuesReceived = expectation(description: "Values received")

    service.liveValue(for: \.pointReleaseXcodeExtensionToDebugApp)
      .sink { value in
        receivedValues.append(value)
        if receivedValues.count == 2 {
          valuesReceived.fulfill()
        }
      }
      .store(in: &cancellables)

    // Initial value should be received
    #expect(receivedValues.count == 1)
    #expect(receivedValues.first == false)

    // Update value
    var settings = service.values()
    settings.pointReleaseXcodeExtensionToDebugApp = true
    let data = try JSONEncoder().encode(settings)
    sharedUserDefaults.set(data, forKey: DefaultSettingsService.Keys.appWideSettings)
    sharedUserDefaults.set(true, forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)

    try await fulfillment(of: [valuesReceived])
    #expect(receivedValues == [false, true])
  }

  @Test("All live values update when settings change")
  @MainActor
  func test_allLiveValuesUpdate() async throws {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    // Test live all values
    var cancellables = Set<AnyCancellable>()
    var receivedSettings: [Settings] = []
    let settingsReceived = expectation(description: "Settings received")

    service.liveValues()
      .sink { settings in
        receivedSettings.append(settings)
        if receivedSettings.count == 2 {
          settingsReceived.fulfill()
        }
      }
      .store(in: &cancellables)

    // Initial value should be received
    #expect(receivedSettings.count == 1)
    #expect(receivedSettings[0].pointReleaseXcodeExtensionToDebugApp == false)

    // Update value
    service.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: true)

    try await fulfillment(of: [settingsReceived])
    #expect(receivedSettings.count == 2)
    #expect(receivedSettings[0].pointReleaseXcodeExtensionToDebugApp == false)
    #expect(receivedSettings[1].pointReleaseXcodeExtensionToDebugApp == true)
  }

  @Test("All provider API keys are stored securely")
  @MainActor
  func test_allProviderApiKeysStoredSecurely() async throws {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    let anthropicSettings = LLMProviderSettings(
      apiKey: "anthropic-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 1)
    let openAISettings = LLMProviderSettings(
      apiKey: "openai-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 2)
    let openRouterSettings = LLMProviderSettings(
      apiKey: "openrouter-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 3)
    let groqSettings = LLMProviderSettings(
      apiKey: "groq-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 4)
    let geminiSettings = LLMProviderSettings(
      apiKey: "gemini-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 5)

    let exp = expectation(description: "Storage updated")
    let updateCount = Atomic(0)
    let cancellable = sharedUserDefaults.onChange {
      if updateCount.increment() == 3 {
        exp.fulfill()
      }
    }

    var newSettings = service.value(for: \.llmProviderSettings)
    newSettings[.anthropic] = anthropicSettings
    newSettings[.openAI] = openAISettings
    newSettings[.openRouter] = openRouterSettings
    newSettings[.groq] = groqSettings
    newSettings[.gemini] = geminiSettings
    service.update(setting: \.llmProviderSettings, to: newSettings)

    // Verify all API keys are accessible
    #expect(service.value(for: \.llmProviderSettings[.anthropic]?.apiKey) == "anthropic-secret-key")
    #expect(service.value(for: \.llmProviderSettings[.openAI]?.apiKey) == "openai-secret-key")
    #expect(service.value(for: \.llmProviderSettings[.openRouter]?.apiKey) == "openrouter-secret-key")
    #expect(service.value(for: \.llmProviderSettings[.groq]?.apiKey) == "groq-secret-key")
    #expect(service.value(for: \.llmProviderSettings[.gemini]?.apiKey) == "gemini-secret-key")

    try await fulfillment(of: exp)

    // Verify all keys are stored securely in keychain
    let secureStorage = sharedUserDefaults.dumpSecureStorage()
    #expect(secureStorage["ANTHROPIC_API_KEY"] == "anthropic-secret-key")
    #expect(secureStorage["OPENAI_API_KEY"] == "openai-secret-key")
    #expect(secureStorage["OPENROUTER_API_KEY"] == "openrouter-secret-key")
    #expect(secureStorage["GROQ_API_KEY"] == "groq-secret-key")
    #expect(secureStorage["GEMINI_API_KEY"] == "gemini-secret-key")

    // Verify the public settings contain key references, not actual keys
    let data = try #require(sharedUserDefaults.dumpStorage()["appWideSettings"] as? Data)
    data.expectToMatch("""
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates": true,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "fileEditMode": "direct I/O",
        "inactiveModels" : [],
        "keyboardShortcuts": {},
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "ANTHROPIC_API_KEY",
            "createdOrder" : 1
          },
          "gemini" : {
            "apiKey" : "GEMINI_API_KEY",
            "createdOrder" : 5
          },
          "groq" : {
            "apiKey" : "GROQ_API_KEY",
            "createdOrder" : 4
          },
          "openai" : {
            "apiKey" : "OPENAI_API_KEY",
            "createdOrder" : 2
          },
          "openrouter" : {
            "apiKey" : "OPENROUTER_API_KEY",
            "createdOrder" : 3
          }
        },
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {},
        "reasoningModels" : {},
        "toolPreferences" : []
      }
      """)
    _ = cancellable
  }
}

extension DefaultSettingsService {
  convenience init(sharedUserDefaults: UserDefaultsI = MockUserDefaults()) {
    self.init(sharedUserDefaults: sharedUserDefaults, releaseSharedUserDefaults: nil)
  }
}
