// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import LLMFoundation
import SwiftTesting
import Testing
@testable import SettingsServiceInterface

struct SettingsServiceMockTests {

  @Test("Direct value access")
  func test_settingValues() {
    // Setup
    let defaultSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "default-key",
          baseUrl: "https://api.anthropic.com",
          executable: nil,
          createdOrder: 1),
      ])

    let sut = MockSettingsService(defaultSettings: defaultSettings)

    // Test initial values
    #expect(sut.value(for: \Settings.pointReleaseXcodeExtensionToDebugApp) == false)
    #expect(sut.value(for: \Settings.llmProviderSettings[.anthropic]?.apiKey) == "default-key")
    #expect(sut.value(for: \Settings.llmProviderSettings[.anthropic]?.baseUrl) == "https://api.anthropic.com")
    #expect(sut.value(for: \Settings.llmProviderSettings[.openAI]) == nil)

    // Test updating values
    sut.update(setting: \Settings.pointReleaseXcodeExtensionToDebugApp, to: true)

    let newAnthropicSettings = AIProviderSettings(
      apiKey: "new-key",
      baseUrl: "https://api.anthropic.com/v1",
      executable: nil,
      createdOrder: 1)

    var newSettings = sut.value(for: \Settings.llmProviderSettings)
    newSettings[.anthropic] = newAnthropicSettings
    sut.update(setting: \Settings.llmProviderSettings, to: newSettings)

    #expect(sut.value(for: \Settings.pointReleaseXcodeExtensionToDebugApp) == true)
    #expect(sut.value(for: \Settings.llmProviderSettings[.anthropic]?.apiKey) == "new-key")
    #expect(sut.value(for: \Settings.llmProviderSettings[.anthropic]?.baseUrl) == "https://api.anthropic.com/v1")

    // Test resetting individual setting
    sut.resetToDefault(setting: \Settings.pointReleaseXcodeExtensionToDebugApp)
    #expect(sut.value(for: \Settings.pointReleaseXcodeExtensionToDebugApp) == false)
    #expect(sut.value(for: \Settings.llmProviderSettings[.anthropic]?.apiKey) == "new-key") // Unchanged

    // Test resetting all settings
    sut.resetAllToDefault()
    #expect(sut.value(for: \Settings.pointReleaseXcodeExtensionToDebugApp) == false)
    #expect(sut.value(for: \Settings.llmProviderSettings[.anthropic]?.apiKey) == "default-key")
    #expect(sut.value(for: \Settings.llmProviderSettings[.anthropic]?.baseUrl) == "https://api.anthropic.com")
    #expect(sut.value(for: \Settings.llmProviderSettings[.openAI]) == nil)
  }

  @Test("All values access")
  func test_allValues() {
    // Setup
    let defaultSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "default-key",
          baseUrl: "https://api.anthropic.com",
          executable: nil,
          createdOrder: 1),
      ])

    let sut = MockSettingsService(defaultSettings: defaultSettings)

    // Test getting all values
    let allSettings = sut.values()
    #expect(allSettings.pointReleaseXcodeExtensionToDebugApp == false)
    #expect(allSettings.llmProviderSettings[.anthropic]?.apiKey == "default-key")
    #expect(allSettings.llmProviderSettings[.anthropic]?.baseUrl == "https://api.anthropic.com")
    #expect(allSettings.llmProviderSettings[.openAI] == nil)

    // Test updating and getting all values
    sut.update(setting: \Settings.pointReleaseXcodeExtensionToDebugApp, to: true)
    let updatedSettings = sut.values()
    #expect(updatedSettings.pointReleaseXcodeExtensionToDebugApp == true)
  }

  @Test("Live value updates")
  func test_liveValues() async throws {
    // Setup
    let defaultSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "default-key",
          baseUrl: "https://api.anthropic.com",
          executable: nil,
          createdOrder: 1),
      ])

    let sut = MockSettingsService(defaultSettings: defaultSettings)

    // Test live values
    var cancellables = Set<AnyCancellable>()
    var receivedValues = [Bool]()
    let valuesReceived = expectation(description: "Values received")

    sut.liveValue(for: \Settings.pointReleaseXcodeExtensionToDebugApp)
      .sink { value in
        receivedValues.append(value)
        if receivedValues.count == 3 {
          valuesReceived.fulfill()
        }
      }
      .store(in: &cancellables)

    // Initial value should be received
    #expect(receivedValues.count == 1)
    #expect(receivedValues.first == false)

    // Update value
    sut.update(setting: \Settings.pointReleaseXcodeExtensionToDebugApp, to: true)

    // Reset value
    sut.resetToDefault(setting: \Settings.pointReleaseXcodeExtensionToDebugApp)

    try await fulfillment(of: [valuesReceived])
    #expect(receivedValues == [false, true, false])
  }

  @Test("Live all values updates")
  func test_liveAllValues() async throws {
    // Setup
    let defaultSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "default-key",
          baseUrl: "https://api.anthropic.com",
          executable: nil,
          createdOrder: 1),
      ])

    let sut = MockSettingsService(defaultSettings: defaultSettings)

    // Test live all values
    var cancellables = Set<AnyCancellable>()
    var receivedSettings = [Settings]()
    let settingsReceived = expectation(description: "Settings received")

    sut.liveValues()
      .sink { settings in
        receivedSettings.append(settings)
        if receivedSettings.count == 3 {
          settingsReceived.fulfill()
        }
      }
      .store(in: &cancellables)

    // Initial value should be received
    #expect(receivedSettings.count == 1)
    #expect(receivedSettings[0].pointReleaseXcodeExtensionToDebugApp == false)

    // Update value
    sut.update(setting: \Settings.pointReleaseXcodeExtensionToDebugApp, to: true)

    // Reset all values
    sut.resetAllToDefault()

    try await fulfillment(of: [settingsReceived])
    #expect(receivedSettings.count == 3)
    #expect(receivedSettings[0].pointReleaseXcodeExtensionToDebugApp == false)
    #expect(receivedSettings[1].pointReleaseXcodeExtensionToDebugApp == true)
    #expect(receivedSettings[2].pointReleaseXcodeExtensionToDebugApp == false)
  }

  @Test("FileEditMode setting in Settings")
  func test_fileEditModeSetting() {
    // Test default value
    let defaultSettings = Settings(pointReleaseXcodeExtensionToDebugApp: false)
    #expect(defaultSettings.fileEditMode == .directIO)

    // Test with custom value
    let customSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      fileEditMode: .xcodeExtension)
    #expect(customSettings.fileEditMode == .xcodeExtension)

    // Test with MockSettingsService
    let sut = MockSettingsService(defaultSettings: customSettings)
    #expect(sut.value(for: \Settings.fileEditMode) == .xcodeExtension)

    // Test updating the setting
    sut.update(setting: \Settings.fileEditMode, to: .xcodeExtension)
    #expect(sut.value(for: \Settings.fileEditMode) == .xcodeExtension)
  }

  @Test("FileEditMode live updates")
  func test_fileEditModeLiveUpdates() async throws {
    let initialSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      fileEditMode: .xcodeExtension)
    let sut = MockSettingsService(defaultSettings: initialSettings)

    var cancellables = Set<AnyCancellable>()
    var receivedModes = [FileEditMode]()
    let modesReceived = expectation(description: "File edit modes received")

    sut.liveValue(for: \Settings.fileEditMode)
      .sink { mode in
        receivedModes.append(mode)
        if receivedModes.count == 3 {
          modesReceived.fulfill()
        }
      }
      .store(in: &cancellables)

    // Initial value should be received
    #expect(receivedModes.count == 1)
    #expect(receivedModes.first == .xcodeExtension)

    // Update to direct I/O
    sut.update(setting: \Settings.fileEditMode, to: .directIO)

    // Reset to default
    sut.resetToDefault(setting: \Settings.fileEditMode)

    try await fulfillment(of: [modesReceived])
    #expect(receivedModes == [.xcodeExtension, .directIO, .xcodeExtension])
  }
}
