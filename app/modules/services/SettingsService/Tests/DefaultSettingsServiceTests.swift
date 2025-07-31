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

  @Test("API keys are stored securely")
  @MainActor
  func test_apiKeysStoredSecurely() async throws {
    // Setup
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(sharedUserDefaults: sharedUserDefaults)

    let anthropicSettings = LLMProviderSettings(
      apiKey: "secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 1)
    let exp = expectation(description: "Storage updated")
    let updateCount = Atomic(0)
    let cancellable = sharedUserDefaults.onChange {
      if updateCount.increment() == 3 {
        exp.fulfill()
      }
    }

    var newSettings = service.value(for: \.llmProviderSettings)
    newSettings[.anthropic] = anthropicSettings
    service.update(setting: \.llmProviderSettings, to: newSettings)

    // Verify
    #expect(service.value(for: \.llmProviderSettings[.anthropic]?.apiKey) == "secret-key")
    try await fulfillment(of: exp)
    #expect(sharedUserDefaults.dumpSecureStorage() == ["ANTHROPIC_API_KEY": "secret-key"])
    let data = try #require(sharedUserDefaults.dumpStorage()["appWideSettings"] as? Data)
    data.expectToMatch("""
      {
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "ANTHROPIC_API_KEY",
            "createdOrder" : 1
          }
        },
        "allowAnonymousAnalytics" : true,
        "customInstructions" : {},
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "automaticallyCheckForUpdates": true,
        "preferedProviders" : {},
        "reasoningModels" : {},
        "inactiveModels" : [],
        "toolPreferences" : [],
        "fileEditMode": "direct I/O" 
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
