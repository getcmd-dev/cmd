// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import Foundation
import FoundationInterfaces
import LLMFoundation
import SettingsServiceInterface
import SwiftTesting
import Testing
@testable import SettingsFeature

// MARK: - SettingsViewModelTests

@MainActor
struct SettingsViewModelTests {

  @Test("initializes with settings from service")
  func test_initialization_withSettings() {
    let initialSettings = SettingsServiceInterface.Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false)
    let mockSettingsService = MockSettingsService(initialSettings)
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    #expect(viewModel.settings.pointReleaseXcodeExtensionToDebugApp == true)
    #expect(viewModel.settings.allowAnonymousAnalytics == false)
  }

  @Test("initializes user defaults properties correctly")
  func test_initialization_withUserDefaults() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    mockUserDefaults.set(true, forKey: .repeatLastLLMInteraction)
    mockUserDefaults.set(false, forKey: .hasCompletedOnboardingUserDefaultsKey)

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    #expect(viewModel.repeatLastLLMInteraction == true)
    #expect(viewModel.showOnboardingScreenAgain == true) // Inverted logic
  }

  @Test("allowAnonymousAnalytics setter updates settings service")
  func test_allowAnonymousAnalytics_setter() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    viewModel.allowAnonymousAnalytics = true

    #expect(viewModel.allowAnonymousAnalytics == true)
    #expect(mockSettingsService.value(for: \.allowAnonymousAnalytics) == true)
  }

  @Test("automaticallyCheckForUpdates getter returns correct value")
  func test_automaticallyCheckForUpdates_getter() {
    let initialSettings = SettingsServiceInterface.Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      automaticallyCheckForUpdates: false)
    let mockSettingsService = MockSettingsService(initialSettings)
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    #expect(viewModel.automaticallyCheckForUpdates == false)
  }

  @Test("automaticallyCheckForUpdates setter updates settings service")
  func test_automaticallyCheckForUpdates_setter() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    viewModel.automaticallyCheckForUpdates = false

    #expect(viewModel.automaticallyCheckForUpdates == false)
    #expect(mockSettingsService.value(for: \.automaticallyCheckForUpdates) == false)
  }

  @Test("repeatLastLLMInteraction setter updates user defaults")
  func test_repeatLastLLMInteraction_setter() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    viewModel.repeatLastLLMInteraction = true

    #expect(mockUserDefaults.bool(forKey: .repeatLastLLMInteraction) == true)
  }

  @Test("showOnboardingScreenAgain setter updates user defaults with inverted logic")
  func test_showOnboardingScreenAgain_setter() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    viewModel.showOnboardingScreenAgain = false

    // Should set hasCompletedOnboardingUserDefaultsKey to true (inverted)
    #expect(mockUserDefaults.bool(forKey: .hasCompletedOnboardingUserDefaultsKey) == true)

    viewModel.showOnboardingScreenAgain = true

    // Should set hasCompletedOnboardingUserDefaultsKey to false (inverted)
    #expect(mockUserDefaults.bool(forKey: .hasCompletedOnboardingUserDefaultsKey) == false)
  }

  @Test("pointReleaseXcodeExtensionToDebugApp setter updates settings service")
  func test_pointReleaseXcodeExtensionToDebugApp_setter() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    viewModel.pointReleaseXcodeExtensionToDebugApp = true

    #expect(viewModel.pointReleaseXcodeExtensionToDebugApp == true)
    #expect(mockSettingsService.value(for: \.pointReleaseXcodeExtensionToDebugApp) == true)
  }

  @Test("showToolInputCopyButtonInRelease setter updates user defaults")
  func test_showToolInputCopyButtonInRelease_setter() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    viewModel.showToolInputCopyButtonInRelease = true

    #expect(mockUserDefaults.bool(forKey: .showToolInputCopyButtonInRelease) == true)
  }

  @Test("fileEditMode setter updates settings service")
  func test_fileEditMode_setter() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    // Test setting to direct I/O
    viewModel.fileEditMode = .directIO
    #expect(viewModel.fileEditMode == .directIO)
    #expect(mockSettingsService.value(for: \.fileEditMode) == .directIO)

    // Test setting to Xcode extension
    viewModel.fileEditMode = .xcodeExtension
    #expect(viewModel.fileEditMode == .xcodeExtension)
    #expect(mockSettingsService.value(for: \.fileEditMode) == .xcodeExtension)
  }

  @Test("keyboardShortcuts setter updates settings service")
  func test_keyboardShortcuts_setter() {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    let shortcut = SettingsServiceInterface.Settings.KeyboardShortcut(key: "i", modifiers: [.command, .shift])
    viewModel.keyboardShortcuts = [.addContextToCurrentChat: shortcut]

    let value = mockSettingsService.value(for: \.keyboardShortcuts)
    #expect(value[.addContextToCurrentChat] == shortcut)
  }

  @Test("observes live settings updates")
  func test_liveSettingsUpdates() async throws {
    let mockSettingsService = MockSettingsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      SettingsViewModel()
    }

    // Update settings through the service
    let newSettings = SettingsServiceInterface.Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true)
    mockSettingsService.update(to: newSettings)

    // Wait for the settings change
    try await viewModel.wait(for: \.settings.allowAnonymousAnalytics, toBe: true)

    #expect(viewModel.settings.allowAnonymousAnalytics == true)
  }

  @Test("AllLLMProviderSettings nextCreatedOrder returns correct value")
  func test_nextCreatedOrder() {
    let emptySettings: AllLLMProviderSettings = [:]
    #expect(emptySettings.nextCreatedOrder == 1)

    let settingsWithProviders: AllLLMProviderSettings = [
      LLMProvider.openAI: LLMProviderSettings(
        apiKey: "key1",
        baseUrl: nil,
        executable: nil,
        createdOrder: 5),
      LLMProvider.anthropic: LLMProviderSettings(
        apiKey: "key2",
        baseUrl: nil,
        executable: nil,
        createdOrder: 3),
    ]
    #expect(settingsWithProviders.nextCreatedOrder == 6)
  }
}
