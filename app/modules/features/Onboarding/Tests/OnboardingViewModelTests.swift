// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import DependenciesTestSupport
import Foundation
import FoundationInterfaces
import LLMServiceInterface
import PermissionsServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
@testable import Onboarding

// MARK: - OnboardingViewModelTests

@Suite("OnboardingViewModelTests", .dependencies { $0.setupDefaultDependencies() })
struct OnboardingViewModelTests {

  @MainActor
  @Test("initializing with default parameters starts at welcome step")
  func test_initialization_withDefaultParameters() {
    var onDoneCalled = false

    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { onDoneCalled = true })

    #expect(viewModel.currentStep == .welcome)
    #expect(viewModel.isAccessibilityPermissionGranted == false)
    #expect(viewModel.isXcodeExtensionPermissionGranted == false)
    #expect(onDoneCalled == false)
  }

  @MainActor
  @Test("moving to next step from welcome with all permissions granted", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension, .xcodeAutomation])
  })
  func test_handleMoveToNextStep_fromWelcome() {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    #expect(viewModel.currentStep == .welcome)

    // Move to osPermissions
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .osPermissions)

    // Since all permissions are granted, can immediately move to next step
    #expect(viewModel.canGoToNextStep == true)
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("moving to next step from setupComplete calls onDone and sets user defaults", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension, .xcodeAutomation])
    $0.llmService = MockLLMService(activeModels: [.gpt])
    $0.settingsService = MockSettingsService(Settings(codeCompletionProviderId: "test-provider"))
  })
  func test_handleMoveToNextStep_fromSetupComplete() throws {
    @Dependency(\.userDefaults) var userDefaults
    let mockUserDefaults = try #require(userDefaults as? MockUserDefaults)

    var onDoneCalled = false
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { onDoneCalled = true })

    // welcome -> osPermissions
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .osPermissions)
    // osPermissions -> providersSetup (since all permissions are granted)
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)
    // providersSetup -> autocompletion (since models are available)
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .autocompletion)
    // autocompletion -> setupComplete (since autocompletion provider is set)
    viewModel.handleMoveToNextStep()

    #expect(viewModel.currentStep == .setupComplete)
    #expect(onDoneCalled == false)

    viewModel.handleMoveToNextStep() // setupComplete -> done

    #expect(onDoneCalled == true)
    #expect(mockUserDefaults.bool(forKey: .hasCompletedOnboardingUserDefaultsKey) == true)
  }

  @MainActor
  @Test("step progression follows correct order when permissions are missing")
  func test_stepProgression_withMissingPermissions() async throws {
    @Dependency(\.permissionsService) var permissionsService
    let mockPermissionsService = try #require(permissionsService as? MockPermissionsService)

    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    #expect(viewModel.currentStep == .welcome)

    viewModel.handleMoveToNextStep() // welcome -> osPermissions
    #expect(viewModel.currentStep == .osPermissions)

    // Grant accessibility permission
    mockPermissionsService.set(permission: .accessibility, status: .grantedEnabled)

    // Wait for accessibility to be granted
    try await viewModel.wait(for: \.isAccessibilityPermissionGranted, toBe: true)

    // Grant Xcode extension permission
    mockPermissionsService.set(permission: .xcodeExtension, status: .grantedEnabled)

    // Wait for xcode extension to be granted
    try await viewModel.wait(for: \.isXcodeExtensionPermissionGranted, toBe: true)

    // Grant Xcode automation permission
    mockPermissionsService.set(permission: .xcodeAutomation, status: .grantedEnabled)

    // Wait for xcode automation to be granted
    try await viewModel.wait(for: \.isXcodeAIProviderPermissionGranted, toBe: true)

    // Now move to next step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("step progression allows moving through osPermissions when already granted", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension, .xcodeAutomation])
  })
  func test_stepProgression_withGrantedPermissions() {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    #expect(viewModel.currentStep == .welcome)

    // welcome -> osPermissions
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .osPermissions)

    // Can immediately move to next since permissions are granted
    #expect(viewModel.canGoToNextStep == true)
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("step progression doesn't skip provider setup when models are available", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension, .xcodeAutomation])
    $0.llmService = MockLLMService(activeModels: [.gpt])
  })
  func test_stepProgression_withAvailableModels() async throws {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    #expect(viewModel.currentStep == .welcome)

    // welcome -> osPermissions
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .osPermissions)

    // osPermissions -> providersSetup (does not skip providers, even though they are already configured)
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("skipAllRemainingSteps moves directly to setupComplete")
  func test_skipAllRemainingSteps() {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    #expect(viewModel.currentStep == .welcome)

    viewModel.skipAllRemainingSteps()

    #expect(viewModel.currentStep == .setupComplete)
  }

  @MainActor
  @Test("handleRequestAccessibilityPermission calls permissions service")
  func test_handleRequestAccessibilityPermission() async throws {
    @Dependency(\.permissionsService) var permissionsService
    let mockPermissionsService = try #require(permissionsService as? MockPermissionsService)

    let callbackExpectation = expectation(description: "Accessibility permission should be requested")
    mockPermissionsService.onRequestAccessibilityPermission = {
      callbackExpectation.fulfill()
    }
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    viewModel.handleRequestAccessibilityPermission()

    // Wait for async callback
    try await fulfillment(of: [callbackExpectation])
  }

  @MainActor
  @Test("handleRequestXcodeExtensionPermission calls permissions service")
  func test_handleRequestXcodeExtensionPermission() async throws {
    @Dependency(\.permissionsService) var permissionsService
    let mockPermissionsService = try #require(permissionsService as? MockPermissionsService)

    let callbackExpectation = expectation(description: "Xcode extension permission should be requested")
    mockPermissionsService.onRequestXcodeExtensionPermission = {
      callbackExpectation.fulfill()
    }
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    viewModel.handleRequestXcodeExtensionPermission()

    // Wait for async callback
    try await fulfillment(of: [callbackExpectation])
  }

  @MainActor
  @Test("accessibility permission status changes trigger step updates")
  func test_accessibilityPermissionStatusChanges() async throws {
    @Dependency(\.permissionsService) var permissionsService
    let mockPermissionsService = try #require(permissionsService as? MockPermissionsService)

    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    // Move to osPermissions step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .osPermissions)
    #expect(viewModel.isAccessibilityPermissionGranted == false)

    // Grant accessibility permission
    mockPermissionsService.set(permission: .accessibility, status: .grantedEnabled)
    // Wait for async update
    try await viewModel.wait(for: \.isAccessibilityPermissionGranted, toBe: true)

    #expect(viewModel.isAccessibilityPermissionGranted == true)
    // Step should still be osPermissions until all required permissions are granted
    #expect(viewModel.currentStep == .osPermissions)
  }

  @MainActor
  @Test("xcode extension permission status changes trigger step updates", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility])
  })
  func test_xcodeExtensionPermissionStatusChanges() async throws {
    @Dependency(\.permissionsService) var permissionsService
    let mockPermissionsService = try #require(permissionsService as? MockPermissionsService)

    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    // Move to osPermissions step (accessibility is already granted in dependencies)
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .osPermissions)
    #expect(viewModel.isXcodeExtensionPermissionGranted == false)

    // Grant xcode extension permission
    mockPermissionsService.set(permission: .xcodeExtension, status: .grantedEnabled)
    // Wait for async update
    try await viewModel.wait(for: \.isXcodeExtensionPermissionGranted, toBe: true)

    #expect(viewModel.isXcodeExtensionPermissionGranted == true)
    // Step should still be osPermissions - need to manually move to next step
    #expect(viewModel.currentStep == .osPermissions)
  }

  @MainActor
  @Test("available models changes trigger step updates", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension, .xcodeAutomation])
  })
  func test_availableModelsChanges() async throws {
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    // welcome -> osPermissions
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .osPermissions)

    // osPermissions -> providersSetup
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)

    // Add an active model
    mockLLMService._activeModels.send([.gpt])
    try await viewModel.wait(for: \.hasSetupAIProvider, toBe: true)

    // Can now move to next step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .autocompletion)
  }

  @MainActor
  @Test("skipping xcode extension and AI provider permissions allows moving to next step", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility])
  })
  func test_skipXcodeExtensionFromPermissionStep() {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    // Move to osPermissions step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .osPermissions)

    // Can't move to next step yet - missing xcode extension and AI provider permissions
    #expect(viewModel.canGoToNextStep == false)

    // Skip xcode extension permissions
    viewModel.handleSkipXcodeExtensionPermissions()
    #expect(viewModel.canGoToNextStep == false) // Still can't move - need to skip AI provider too

    // Skip AI provider permissions
    viewModel.handleSkipXcodeAIProviderPermissions()
    #expect(viewModel.canGoToNextStep == true)

    // Now can move to next step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)
  }
}

extension DependencyValues {
  fileprivate mutating func setupDefaultDependencies() {
    userDefaults = MockUserDefaults()
    permissionsService = MockPermissionsService()
    llmService = MockLLMService()
    settingsService = MockSettingsService()
  }
}
