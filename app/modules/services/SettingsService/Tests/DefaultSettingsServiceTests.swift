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
    let fileManager = MockFileManager()
    let sharedUserDefaults = MockUserDefaults()

    // Test
    let service = DefaultSettingsService(fileManager: fileManager, sharedUserDefaults: sharedUserDefaults)

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
    let groqSettings = AIProviderSettings(
      apiKey: "test-groq-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 1)
    let geminiSettings = AIProviderSettings(
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
    #expect(secureStorage["cmd-keychain-key-GROQ_API_KEY"] == "test-groq-key")
    #expect(secureStorage["cmd-keychain-key-GEMINI_API_KEY"] == "test-gemini-key")
  }

  @Test("Updates and retrieves values")
  @MainActor
  func test_updateAndRetrieveValues() {
    // Setup
    let service = DefaultSettingsService()

    // Test updating values
    service.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: true)

    let anthropicSettings = AIProviderSettings(
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
    let service = DefaultSettingsService()

    // Set initial values
    service.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: true)
    let anthropicSettings = AIProviderSettings(
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
    let service = DefaultSettingsService()

    // Set initial values
    service.update(setting: \.pointReleaseXcodeExtensionToDebugApp, to: true)
    let anthropicSettings = AIProviderSettings(
      apiKey: "test-key",
      baseUrl: "https://api.anthropic.com/test",
      executable: nil,
      createdOrder: 1)
    let openAISettings = AIProviderSettings(
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
    let service = DefaultSettingsService()

    // Test live values
    var cancellables = Set<AnyCancellable>()
    var receivedValues = [Bool]()
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
    var receivedValues = [Bool]()
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

    // Update value by writing to both new storage locations
    // Update internal settings in UserDefaults
    let internalData = try JSONEncoder().encode(InternalSettings(pointReleaseXcodeExtensionToDebugApp: true))
    sharedUserDefaults.set(internalData, forKey: DefaultSettingsService.Keys.internalSettings)
    sharedUserDefaults.set(true, forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)

    try await fulfillment(of: [valuesReceived])
    #expect(receivedValues == [false, true])
  }

  @Test("All live values update when settings change")
  @MainActor
  func test_allLiveValuesUpdate() async throws {
    // Setup
    let service = DefaultSettingsService()

    // Test live all values
    var cancellables = Set<AnyCancellable>()
    var receivedSettings = [Settings]()
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
    let fileManager = MockFileManager()
    let settingsDirLocation = fileManager.homeDirectoryForCurrentUser.appending(path: ".cmd")
    let settingsFileLocation = settingsDirLocation.appending(path: "settings.json")
    // Create the .cmd directory
    try fileManager.createDirectory(at: settingsDirLocation, withIntermediateDirectories: true, attributes: nil)
    let sharedUserDefaults = MockUserDefaults()
    let service = DefaultSettingsService(
      fileManager: fileManager,
      settingsFileLocation: settingsFileLocation,
      sharedUserDefaults: sharedUserDefaults,
      releaseSharedUserDefaults: nil)

    let anthropicSettings = AIProviderSettings(
      apiKey: "anthropic-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 1)
    let openAISettings = AIProviderSettings(
      apiKey: "openai-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 2)
    let openRouterSettings = AIProviderSettings(
      apiKey: "openrouter-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 3)
    let groqSettings = AIProviderSettings(
      apiKey: "groq-secret-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 4)
    let geminiSettings = AIProviderSettings(
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
    #expect(secureStorage["cmd-keychain-key-ANTHROPIC_API_KEY"] == "anthropic-secret-key")
    #expect(secureStorage["cmd-keychain-key-OPENAI_API_KEY"] == "openai-secret-key")
    #expect(secureStorage["cmd-keychain-key-OPENROUTER_API_KEY"] == "openrouter-secret-key")
    #expect(secureStorage["cmd-keychain-key-GROQ_API_KEY"] == "groq-secret-key")
    #expect(secureStorage["cmd-keychain-key-GEMINI_API_KEY"] == "gemini-secret-key")

    // Verify internal settings are written to UserDefaults
    let internalData = try #require(sharedUserDefaults.dumpStorage()["internalSettings"] as? Data)
    internalData.expectToMatch("""
      {
        "pointReleaseXcodeExtensionToDebugApp" : false
      }
      """)

    // Verify external settings are written to disk (only non-default values)
    let externalData = try fileManager.read(dataFrom: settingsFileLocation)
    externalData.expectToMatch("""
      {
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "cmd-keychain-key-ANTHROPIC_API_KEY",
            "createdOrder" : 1
          },
          "gemini" : {
            "apiKey" : "cmd-keychain-key-GEMINI_API_KEY",
            "createdOrder" : 5
          },
          "groq" : {
            "apiKey" : "cmd-keychain-key-GROQ_API_KEY",
            "createdOrder" : 4
          },
          "openai" : {
            "apiKey" : "cmd-keychain-key-OPENAI_API_KEY",
            "createdOrder" : 2
          },
          "openrouter" : {
            "apiKey" : "cmd-keychain-key-OPENROUTER_API_KEY",
            "createdOrder" : 3
          }
        }
      }
      """)
    _ = cancellable
  }

  @Test("API keys are properly deserialized from new storage format")
  @MainActor
  func test_apiKeyDeserializationFromNewStorageFormat() async throws {
    // given
    let fileManager = MockFileManager()
    let settingsDirLocation = fileManager.homeDirectoryForCurrentUser.appending(path: ".cmd")
    let settingsFileLocation = settingsDirLocation.appending(path: "settings.json")
    // Create the .cmd directory
    try fileManager.createDirectory(at: settingsDirLocation, withIntermediateDirectories: true, attributes: nil)
    let sharedUserDefaults = MockUserDefaults()

    // Store API keys in keychain format
    sharedUserDefaults.securelySave("test-anthropic-key", forKey: "cmd-keychain-key-ANTHROPIC_API_KEY")
    sharedUserDefaults.securelySave("test-openai-key", forKey: "cmd-keychain-key-OPENAI_API_KEY")
    sharedUserDefaults.securelySave("test-openrouter-key", forKey: "cmd-keychain-key-OPENROUTER_API_KEY")
    sharedUserDefaults.securelySave("test-groq-key", forKey: "cmd-keychain-key-GROQ_API_KEY")
    sharedUserDefaults.securelySave("test-gemini-key", forKey: "cmd-keychain-key-GEMINI_API_KEY")

    // Store internal settings in UserDefaults
    let internalSettingsJSON = """
      {
        "pointReleaseXcodeExtensionToDebugApp" : false
      }
      """
    let internalData = try #require(internalSettingsJSON.data(using: .utf8))
    sharedUserDefaults.set(internalData, forKey: DefaultSettingsService.Keys.internalSettings)

    // Store external settings on disk
    let externalSettingsJSON = """
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates": true,
        "automaticallyUpdateXcodeSettings" : false,
        "fileEditMode": "direct I/O",
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "cmd-keychain-key-ANTHROPIC_API_KEY",
            "createdOrder" : 1
          },
          "openai" : {
            "apiKey" : "cmd-keychain-key-OPENAI_API_KEY",
            "createdOrder" : 2
          },
          "openrouter" : {
            "apiKey" : "cmd-keychain-key-OPENROUTER_API_KEY",
            "createdOrder" : 3
          },
          "groq" : {
            "apiKey" : "cmd-keychain-key-GROQ_API_KEY",
            "createdOrder" : 4
          },
          "gemini" : {
            "apiKey" : "cmd-keychain-key-GEMINI_API_KEY",
            "createdOrder" : 5
          }
        }
      }
      """

    try fileManager.write(string: externalSettingsJSON, to: settingsFileLocation, options: [])

    // when
    let sut = DefaultSettingsService(
      fileManager: fileManager,
      settingsFileLocation: settingsFileLocation,
      sharedUserDefaults: sharedUserDefaults,
      releaseSharedUserDefaults: nil,
      bundle: .testMain)

    // then
    // Verify all provider API keys are properly deserialized from keychain
    #expect(sut.value(for: \.llmProviderSettings[.anthropic]?.apiKey) == "test-anthropic-key")
    #expect(sut.value(for: \.llmProviderSettings[.openAI]?.apiKey) == "test-openai-key")
    #expect(sut.value(for: \.llmProviderSettings[.openRouter]?.apiKey) == "test-openrouter-key")
    #expect(sut.value(for: \.llmProviderSettings[.groq]?.apiKey) == "test-groq-key")
    #expect(sut.value(for: \.llmProviderSettings[.gemini]?.apiKey) == "test-gemini-key")

    // Verify all other settings remain intact
    #expect(sut.value(for: \.llmProviderSettings[.anthropic]?.createdOrder) == 1)
    #expect(sut.value(for: \.llmProviderSettings[.openAI]?.createdOrder) == 2)
    #expect(sut.value(for: \.llmProviderSettings[.openRouter]?.createdOrder) == 3)
    #expect(sut.value(for: \.llmProviderSettings[.groq]?.createdOrder) == 4)
    #expect(sut.value(for: \.llmProviderSettings[.gemini]?.createdOrder) == 5)
  }

  @Test("Xcode extension reads from user defaults")
  @MainActor
  func test_xcodeExtensionReadsFromUserDefaults() async throws {
    // given
    let fileManager = MockFileManager()
    let settingsFileLocation = fileManager.homeDirectoryForCurrentUser.appending(path: ".cmd/settings.json")
    let sharedUserDefaults = MockUserDefaults()

    // Store internal settings in UserDefaults
    let internalSettingsJSON = """
      {
        "pointReleaseXcodeExtensionToDebugApp" : false
      }
      """
    let internalData = try #require(internalSettingsJSON.data(using: .utf8))
    sharedUserDefaults.set(internalData, forKey: DefaultSettingsService.Keys.internalSettings)

    // Store external settings on disk
    let externalSettingsJSON = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates": true,
        "automaticallyUpdateXcodeSettings" : false,
        "fileEditMode": "direct I/O",
        "llmProviderSettings" : {}
      }
      """

    let externalData = try #require(externalSettingsJSON.data(using: .utf8))
    sharedUserDefaults.set(externalData, forKey: DefaultSettingsService.Keys.externalSettingsForSandboxedProcesses)

    // when
    let sut = DefaultSettingsService(
      fileManager: fileManager,
      settingsFileLocation: settingsFileLocation,
      sharedUserDefaults: sharedUserDefaults,
      releaseSharedUserDefaults: nil,
      bundle: .testXcodeExtension)

    // then
    #expect(sut.value(for: \.allowAnonymousAnalytics) == false)
    // Helps ensure that we indeed decoded the value, and didn't fallback to default
    #expect(sut.value(for: \.allowAnonymousAnalytics) != ExternalSettings.defaultSettings.allowAnonymousAnalytics)
  }
}

extension DefaultSettingsService {
  fileprivate convenience init(
    fileManager: FileManagerI = MockFileManager(),
    sharedUserDefaults: UserDefaultsI = MockUserDefaults())
  {
    self.init(
      fileManager: fileManager,
      sharedUserDefaults: sharedUserDefaults,
      releaseSharedUserDefaults: nil)
  }
}

// MARK: - TestBundle

class TestBundle: Bundle, @unchecked Sendable {
  init(_ infoDictionary: [String: Any]?, bundleIdentifier: String) {
    _infoDictionary = infoDictionary
    _bundleIdentifier = bundleIdentifier
    super.init()
  }

  override var infoDictionary: [String: Any]? {
    _infoDictionary
  }

  override var bundleIdentifier: String? {
    _bundleIdentifier
  }

  private let _infoDictionary: [String: Any]?

  private let _bundleIdentifier: String

}

extension Bundle {
  static let testMain: Bundle = TestBundle(
    [
      "XCODE_EXTENSION_PRODUCT_NAME": "Xcode extension",
      "HOST_APP_BUNDLE_IDENTIFIER": "com.test.app",
      "XCODE_EXTENSION_BUNDLE_IDENTIFIER": "com.test.xcode-extension",
      "RELEASE_HOST_APP_BUNDLE_IDENTIFIER": "com.test.app",
      "APP_DISTRIBUTION_CHANNEL": "dev",
    ],
    bundleIdentifier: "com.test.app")
  static let testXcodeExtension: Bundle = TestBundle(
    [
      "XCODE_EXTENSION_PRODUCT_NAME": "Xcode extension",
      "HOST_APP_BUNDLE_IDENTIFIER": "com.test.app",
      "XCODE_EXTENSION_BUNDLE_IDENTIFIER": "com.test.xcode-extension",
      "RELEASE_HOST_APP_BUNDLE_IDENTIFIER": "com.test.app",
      "APP_DISTRIBUTION_CHANNEL": "dev",
    ],
    bundleIdentifier: "com.test.xcode-extension")
}
