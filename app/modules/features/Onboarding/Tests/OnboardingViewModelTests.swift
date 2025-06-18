// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import Foundation
import FoundationInterfaces
import PermissionsServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
@testable import Onboarding

// MARK: - OnboardingViewModelTests

struct OnboardingViewModelTests {

  @MainActor
  @Test("initializing with default parameters starts at welcome step")
  func test_initialization_withDefaultParameters() {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService()
    var onDoneCalled = false

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { onDoneCalled = true })
    }

    #expect(viewModel.currentStep == .welcome)
    #expect(viewModel.isAccessibilityPermissionGranted == false)
    #expect(viewModel.isXcodeExtensionPermissionGranted == false)
    #expect(onDoneCalled == false)
  }

  @MainActor
  @Test("moving to next step from welcome updates hasSkippedWelcomeScreen")
  func test_handleMoveToNextStep_fromWelcome() {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    #expect(viewModel.currentStep == .welcome)

    viewModel.handleMoveToNextStep()

    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("moving to next step from setupComplete calls onDone and sets user defaults")
  func test_handleMoveToNextStep_fromSetupComplete() {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .openAI: LLMProviderSettings(apiKey: "test", baseUrl: nil, createdOrder: 1),
      ]))
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])
    var onDoneCalled = false

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { onDoneCalled = true })
    }

    // Should go directly to setup complete since permissions are granted and models are available
    viewModel.handleMoveToNextStep() // welcome -> setupComplete

    #expect(viewModel.currentStep == .setupComplete)
    #expect(onDoneCalled == false)

    viewModel.handleMoveToNextStep() // setupComplete -> done

    #expect(onDoneCalled == true)
    #expect(mockUserDefaults.bool(forKey: .hasCompletedOnboardingUserDefaultsKey) == true)
  }

  @MainActor
  @Test("step progression follows correct order when permissions are missing")
  func test_stepProgression_withMissingPermissions() async throws {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    #expect(viewModel.currentStep == .welcome)

    viewModel.handleMoveToNextStep() // welcome -> accessibility
    #expect(viewModel.currentStep == .accessibilityPermission)

    // Set up expectation for step change
    let stepChangeExpectation = expectation(description: "Step should change to xcodeExtensionPermission")
    let cancellable = viewModel.didSet(\.currentStep) { step in
      if step == .xcodeExtensionPermission {
        stepChangeExpectation.fulfill()
      }
    }

    // Grant accessibility permission
    mockPermissionsService.set(permission: .accessibility, granted: true)

    // Wait for the step change
    try await fulfillment(of: [stepChangeExpectation])
    cancellable.cancel()

    #expect(viewModel.currentStep == .xcodeExtensionPermission)

    // Set up expectation for next step change
    let nextStepChangeExpectation = expectation(description: "Step should change to providersSetup")
    let nextCancellable = viewModel.didSet(\.currentStep) { step in
      if step == .providersSetup {
        nextStepChangeExpectation.fulfill()
      }
    }

    // Grant Xcode extension permission
    mockPermissionsService.set(permission: .xcodeExtension, granted: true)

    // Wait for the step change
    try await fulfillment(of: [nextStepChangeExpectation])
    nextCancellable.cancel()

    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("step progression skips permissions when already granted")
  func test_stepProgression_withGrantedPermissions() {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    #expect(viewModel.currentStep == .welcome)

    viewModel.handleMoveToNextStep() // welcome -> providers (skipping permissions)
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("step progression moves to setupComplete when models are available")
  func test_stepProgression_withAvailableModels() {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .openAI: LLMProviderSettings(apiKey: "test", baseUrl: nil, createdOrder: 1),
      ]))
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    #expect(viewModel.currentStep == .welcome)

    viewModel.handleMoveToNextStep() // welcome -> setupComplete (skipping providers)
    #expect(viewModel.currentStep == .setupComplete)
  }

  @MainActor
  @Test("skipAllRemainingSteps moves directly to setupComplete")
  func test_skipAllRemainingSteps() {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    #expect(viewModel.currentStep == .welcome)

    viewModel.skipAllRemainingSteps()

    #expect(viewModel.currentStep == .setupComplete)
  }

  @MainActor
  @Test("handleRequestAccessibilityPermission calls permissions service")
  func test_handleRequestAccessibilityPermission() async throws {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService()

    let callbackExpectation = expectation(description: "Accessibility permission should be requested")
    mockPermissionsService.onRequestAccessibilityPermission = {
      callbackExpectation.fulfill()
    }

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    viewModel.handleRequestAccessibilityPermission()

    // Wait for async callback
    try await fulfillment(of: [callbackExpectation])
  }

  @MainActor
  @Test("handleRequestXcodeExtensionPermission calls permissions service")
  func test_handleRequestXcodeExtensionPermission() async throws {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService()

    let callbackExpectation = expectation(description: "Xcode extension permission should be requested")
    mockPermissionsService.onRequestXcodeExtensionPermission = {
      callbackExpectation.fulfill()
    }

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    viewModel.handleRequestXcodeExtensionPermission()

    // Wait for async callback
    try await fulfillment(of: [callbackExpectation])
  }

  @MainActor
  @Test("accessibility permission status changes trigger step updates")
  func test_accessibilityPermissionStatusChanges() async throws {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    // Move to accessibility permission step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .accessibilityPermission)
    #expect(viewModel.isAccessibilityPermissionGranted == false)

    // Set up expectation for permission change
    let permissionChangeExpectation = expectation(description: "Accessibility permission should be granted")
    let permissionCancellable = viewModel.didSet(\.isAccessibilityPermissionGranted) { granted in
      if granted {
        permissionChangeExpectation.fulfill()
      }
    }

    // Grant accessibility permission
    mockPermissionsService.set(permission: .accessibility, granted: true)

    // Wait for async update
    try await fulfillment(of: [permissionChangeExpectation])
    permissionCancellable.cancel()

    #expect(viewModel.isAccessibilityPermissionGranted == true)
    #expect(viewModel.currentStep == .xcodeExtensionPermission)
  }

  @MainActor
  @Test("xcode extension permission status changes trigger step updates")
  func test_xcodeExtensionPermissionStatusChanges() async throws {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    // Move to xcode extension permission step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .xcodeExtensionPermission)
    #expect(viewModel.isXcodeExtensionPermissionGranted == false)

    // Set up expectation for permission change
    let permissionChangeExpectation = expectation(description: "Xcode extension permission should be granted")
    let permissionCancellable = viewModel.didSet(\.isXcodeExtensionPermissionGranted) { granted in
      if granted {
        permissionChangeExpectation.fulfill()
      }
    }

    // Grant xcode extension permission
    mockPermissionsService.set(permission: .xcodeExtension, granted: true)

    // Wait for async update
    try await fulfillment(of: [permissionChangeExpectation])
    permissionCancellable.cancel()

    #expect(viewModel.isXcodeExtensionPermissionGranted == true)
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("available models changes trigger step updates")
  func test_availableModelsChanges() async throws {
    var cancellables = Set<AnyCancellable>()
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    // Move to providers setup step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)

    let canSkipProviderSetupExpectation = expectation(description: "canSkipProviderSetup should be true")
    viewModel.didSet(\.canSkipProviderSetup) { canSkip in
      if canSkip {
        canSkipProviderSetupExpectation.fulfill()
      }
    }.store(in: &cancellables)

    // Add a provider with API key
    var newSettings = mockSettingsService.value(for: \.llmProviderSettings)
    newSettings[.openAI] = LLMProviderSettings(apiKey: "test", baseUrl: nil, createdOrder: 1)
    mockSettingsService.update(setting: \.llmProviderSettings, to: newSettings)
    try await fulfillment(of: canSkipProviderSetupExpectation)

    // Set up expectation for step change
    let stepChangeExpectation = expectation(description: "Step should change to setupComplete")
    viewModel.didSet(\.currentStep) { step in
      if step == .setupComplete {
        stepChangeExpectation.fulfill()
      }
    }.store(in: &cancellables)
    viewModel.handleMoveToNextStep()

    // Wait for async update
    try await fulfillment(of: [stepChangeExpectation])

    #expect(viewModel.currentStep == .setupComplete)
  }

  @MainActor
  @Test("skipping xcode extension from permission step sets skipXcodeExtension flag")
  func test_skipXcodeExtensionFromPermissionStep() {
    let mockUserDefaults = MockUserDefaults()
    let mockSettingsService = MockSettingsService()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility])

    let viewModel = withDependencies {
      $0.userDefaults = mockUserDefaults
      $0.settingsService = mockSettingsService
      $0.permissionsService = mockPermissionsService
    } operation: {
      OnboardingViewModel(bringWindowToFront: { }, onDone: { })
    }

    // Move to xcode extension permission step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .xcodeExtensionPermission)

    // Skip xcode extension
    viewModel.handleMoveToNextStep()

    #expect(viewModel.currentStep == .providersSetup)
  }
}
