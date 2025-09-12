// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import ChatAppEvents
import ChatFoundation
import Combine
import ConcurrencyFoundation
import Dependencies
import FoundationInterfaces
import PermissionsServiceInterface
import SwiftTesting
import Testing
@testable import App

// MARK: - WindowsViewModelTests

@MainActor
struct WindowsViewModelTests {

  @Test("initializes with correct default state")
  func test_initialization_withDefaultState() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    #expect(viewModel.state.isSidePanelVisible == false)
    #expect(viewModel.state.isOnboardingVisible == true) // Should be true because onboarding is not completed by default
  }

  @Test("registers app event handler on initialization")
  func test_initialization_registersEventHandler() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService()
    let mockUserDefaults = MockUserDefaults()

    let handlerRegistered = Atomic(false)
    mockAppEventRegistry.onRegisterHandler = { @Sendable _ in
      handlerRegistered.set(to: true)
    }

    _ = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    #expect(handlerRegistered.value == true)
  }

  @Test("showApplication action shows side panel")
  func test_handleAction_showApplication() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    viewModel.handle(.showApplication)

    #expect(viewModel.state.isSidePanelVisible == true)
  }

  @Test("closeSidePanel action hides side panel")
  func test_handleAction_closeSidePanel() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    // First show the side panel
    viewModel.handle(.showApplication)
    #expect(viewModel.state.isSidePanelVisible == true)

    // Then close it
    viewModel.handle(.closeSidePanel)
    #expect(viewModel.state.isSidePanelVisible == false)
  }

  @Test("accessibilityPermissionChanged with nil value ignores change")
  func test_handleAction_accessibilityPermissionChanged_nilValue() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    let initialState = viewModel.state

    viewModel.handle(.accessibilityPermissionChanged(isGranted: nil))

    // State should remain unchanged
    #expect(viewModel.state.isSidePanelVisible == initialState.isSidePanelVisible)
    #expect(viewModel.state.isOnboardingVisible == initialState.isOnboardingVisible)
  }

  @Test("accessibilityPermissionChanged with false shows onboarding")
  func test_handleAction_accessibilityPermissionChanged_false() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService()
    let mockUserDefaults = MockUserDefaults()

    // Set onboarding as completed
    mockUserDefaults.set(true, forKey: .hasCompletedOnboardingUserDefaultsKey)

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    viewModel.handle(.accessibilityPermissionChanged(isGranted: false))

    #expect(viewModel.state.isOnboardingVisible == true)
  }

  @Test("accessibilityPermissionChanged with true hides onboarding when completed")
  func test_handleAction_accessibilityPermissionChanged_true() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService()
    let mockUserDefaults = MockUserDefaults()

    // Set onboarding as completed
    mockUserDefaults.set(true, forKey: .hasCompletedOnboardingUserDefaultsKey)

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    viewModel.handle(.accessibilityPermissionChanged(isGranted: true))

    #expect(viewModel.state.isOnboardingVisible == false)
  }

  @Test("onboardingDidComplete updates onboarding visibility")
  func test_handleAction_onboardingDidComplete() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService()
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    viewModel.handle(.onboardingDidComplete)

    // Should show side panel and hide onboarding
    #expect(viewModel.state.isSidePanelVisible == true)
    #expect(viewModel.state.isOnboardingVisible == false)
  }

  @Test("onboarding visibility when onboarding not completed")
  func test_isOnboardingVisible_onboardingNotCompleted() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility])
    let mockUserDefaults = MockUserDefaults()

    // Don't set onboarding as completed
    mockUserDefaults.set(false, forKey: .hasCompletedOnboardingUserDefaultsKey)

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    #expect(viewModel.state.isOnboardingVisible == true)
  }

  @Test("onboarding visibility when accessibility permission not granted")
  func test_isOnboardingVisible_accessibilityNotGranted() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [])
    let mockUserDefaults = MockUserDefaults()

    // Set onboarding as completed
    mockUserDefaults.set(true, forKey: .hasCompletedOnboardingUserDefaultsKey)

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    // Trigger accessibility permission change
    viewModel.handle(.accessibilityPermissionChanged(isGranted: false))

    #expect(viewModel.state.isOnboardingVisible == true)
  }

  @Test("onboarding hidden when all conditions met")
  func test_isOnboardingVisible_allConditionsMet() {
    let mockAppEventRegistry = MockAppEventHandlerRegistry()
    let mockPermissionsService = MockPermissionsService(grantedPermissions: [.accessibility])
    let mockUserDefaults = MockUserDefaults()

    // Set onboarding as completed
    mockUserDefaults.set(true, forKey: .hasCompletedOnboardingUserDefaultsKey)

    let viewModel = withDependencies {
      $0.appEventHandlerRegistry = mockAppEventRegistry
      $0.permissionsService = mockPermissionsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      WindowsViewModel()
    }

    // Trigger accessibility permission change to true
    viewModel.handle(.accessibilityPermissionChanged(isGranted: true))

    #expect(viewModel.state.isOnboardingVisible == false)
  }
}
