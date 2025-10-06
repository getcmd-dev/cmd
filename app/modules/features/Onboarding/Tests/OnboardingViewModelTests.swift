// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import DependenciesTestSupport
import Foundation
import FoundationInterfaces
import LLMServiceInterface
import PermissionsServiceInterface
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
  @Test("moving to next step from welcome updates hasSkippedWelcomeScreen", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])
  })
  func test_handleMoveToNextStep_fromWelcome() {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    #expect(viewModel.currentStep == .welcome)

    viewModel.handleMoveToNextStep()

    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("moving to next step from setupComplete calls onDone and sets user defaults", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])
    $0.llmService = MockLLMService(activeModels: [.gpt])
  })
  func test_handleMoveToNextStep_fromSetupComplete() throws {
    @Dependency(\.userDefaults) var userDefaults
    let mockUserDefaults = try #require(userDefaults as? MockUserDefaults)

    var onDoneCalled = false
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { onDoneCalled = true })

    // Should go directly to providers setup since permissions are granted
    viewModel.handleMoveToNextStep() // welcome -> providersSetup
    #expect(viewModel.currentStep == .providersSetup)
    // Should go directly to setup complete since models are available
    viewModel.handleMoveToNextStep() // providersSetup -> setupComplete

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

    viewModel.handleMoveToNextStep() // welcome -> accessibility
    #expect(viewModel.currentStep == .accessibilityPermission)

    // Grant accessibility permission
    mockPermissionsService.set(permission: .accessibility, granted: true)

    // Wait for the step change
    try await viewModel.wait(for: \.currentStep, toBe: .xcodeExtensionPermission)
    #expect(viewModel.currentStep == .xcodeExtensionPermission)

    // Grant Xcode extension permission
    mockPermissionsService.set(permission: .xcodeExtension, granted: true)

    // Wait for the step change
    try await viewModel.wait(for: \.currentStep, toBe: .providersSetup)
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("step progression skips permissions when already granted", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])
  })
  func test_stepProgression_withGrantedPermissions() {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    #expect(viewModel.currentStep == .welcome)

    viewModel.handleMoveToNextStep() // welcome -> providers (skipping permissions)
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("step progression doesn't skip provider setup when models are available", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])
    $0.llmService = MockLLMService(activeModels: [.gpt])
  })
  func test_stepProgression_withAvailableModels() async throws {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    #expect(viewModel.currentStep == .welcome)

    viewModel
      .handleMoveToNextStep() // welcome -> providersSetup (does not skip providers, even though they are already configured)
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

    // Move to accessibility permission step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .accessibilityPermission)
    #expect(viewModel.isAccessibilityPermissionGranted == false)

    // Grant accessibility permission
    mockPermissionsService.set(permission: .accessibility, granted: true)
    // Wait for async update
    try await viewModel.wait(for: \.isAccessibilityPermissionGranted, toBe: true)

    #expect(viewModel.isAccessibilityPermissionGranted == true)
    #expect(viewModel.currentStep == .xcodeExtensionPermission)
  }

  @MainActor
  @Test("xcode extension permission status changes trigger step updates", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility])
  })
  func test_xcodeExtensionPermissionStatusChanges() async throws {
    @Dependency(\.permissionsService) var permissionsService
    let mockPermissionsService = try #require(permissionsService as? MockPermissionsService)

    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    // Move to xcode extension permission step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .xcodeExtensionPermission)
    #expect(viewModel.isXcodeExtensionPermissionGranted == false)

    // Grant xcode extension permission
    mockPermissionsService.set(permission: .xcodeExtension, granted: true)
    // Wait for async update
    try await viewModel.wait(for: \.isXcodeExtensionPermissionGranted, toBe: true)

    #expect(viewModel.isXcodeExtensionPermissionGranted == true)
    #expect(viewModel.currentStep == .providersSetup)
  }

  @MainActor
  @Test("available models changes trigger step updates", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility, .xcodeExtension])
  })
  func test_availableModelsChanges() async throws {
    @Dependency(\.llmService) var llmService
    let mockLLMService = try #require(llmService as? MockLLMService)

    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    // Move to providers setup step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .providersSetup)

    // Add an active model
    mockLLMService._activeModels.send([.gpt])
    try await viewModel.wait(for: \.canSkipProviderSetup, toBe: true)

    viewModel.handleMoveToNextStep()
    // Wait for async update
    try await viewModel.wait(for: \.currentStep, toBe: .setupComplete)

    #expect(viewModel.currentStep == .setupComplete)
  }

  @MainActor
  @Test("skipping xcode extension from permission step sets skipXcodeExtension flag", .dependencies {
    $0.permissionsService = MockPermissionsService(grantedPermissions: [.accessibility])
  })
  func test_skipXcodeExtensionFromPermissionStep() {
    let viewModel = OnboardingViewModel(bringWindowToFront: { }, onDone: { })

    // Move to xcode extension permission step
    viewModel.handleMoveToNextStep()
    #expect(viewModel.currentStep == .xcodeExtensionPermission)

    // Skip xcode extension
    viewModel.handleMoveToNextStep()

    #expect(viewModel.currentStep == .providersSetup)
  }
}

extension DependencyValues {
  fileprivate mutating func setupDefaultDependencies() {
    userDefaults = MockUserDefaults()
    permissionsService = MockPermissionsService()
    llmService = MockLLMService()
  }
}
