// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import FoundationInterfaces
import LoggingServiceInterface
import Observation
import PermissionsServiceInterface
import SettingsServiceInterface

// MARK: - OnboardingStep

enum OnboardingStep {
  case welcome
  case accessibilityPermission
  case providersSetup
  case xcodeExtensionPermission
  case systemEventsPermission
  case setupComplete
}

// MARK: - OnboardingViewModel

@MainActor
@Observable
final class OnboardingViewModel {
  init(
    bringWindowToFront: @escaping @MainActor () -> Void,
    onDone: @escaping @MainActor () -> Void)
  {
    self.onDone = onDone
    self.bringWindowToFront = bringWindowToFront

    @Dependency(\.userDefaults) var userDefaults
    self.userDefaults = userDefaults
    @Dependency(\.settingsService) var settingsService
    self.settingsService = settingsService
    @Dependency(\.permissionsService) var permissionsService
    self.permissionsService = permissionsService

    isAccessibilityPermissionGranted = permissionsService.status(for: .accessibility).currentValue == true
    isXcodeExtensionPermissionGranted = permissionsService.status(for: .xcodeExtension).currentValue == true
    canSkipProviderSetup = !settingsService.value(for: \.availableModels).isEmpty

    currentStep = .welcome
    currentStep = getStep()

    permissionsService.status(for: .accessibility).sink { @Sendable [weak self] status in
      Task { @MainActor in
        guard let self else { return }
        self.isAccessibilityPermissionGranted = status == true
        if status == true, self.currentStep == .accessibilityPermission {
          defaultLogger.record(
            event: "accessibility_permission_granted",
            metadata: [
              "source": "onboarding",
            ])
          self.handleMoveToNextStep()
          self.bringWindowToFront()
        }
      }
    }.store(in: &cancellables)

    permissionsService.status(for: .xcodeExtension).sink { @Sendable [weak self] status in
      Task { @MainActor in
        guard let self else { return }
        self.isXcodeExtensionPermissionGranted = status == true
        if status == true, self.currentStep == .xcodeExtensionPermission {
          defaultLogger.record(
            event: "xcode_extension_permission_granted",
            metadata: [
              "source": "onboarding",
            ])
          self.handleMoveToNextStep()
          self.bringWindowToFront()
        }
      }
    }.store(in: &cancellables)

    settingsService.liveValue(for: \.availableModels).sink { @Sendable [weak self] models in
      Task { @MainActor in
        guard let self else { return }
        if !models.isEmpty {
          self.canSkipProviderSetup = true
        }
      }
    }.store(in: &cancellables)
  }

  private(set) var isXcodeExtensionPermissionGranted: Bool

  private(set) var isAccessibilityPermissionGranted: Bool

  private(set) var canSkipProviderSetup: Bool

  private(set) var hasSkippedProviderSetup = false

  private(set) var currentStep: OnboardingStep

  func handleMoveToNextStep() {
    if currentStep == .welcome {
      hasSkippedWelcomeScreen = true
    }
    if currentStep == .xcodeExtensionPermission {
      skipXcodeExtension = true
    }
    if currentStep == .providersSetup, canSkipProviderSetup {
      hasSkippedProviderSetup = true
    }
    if currentStep == .setupComplete {
      userDefaults.set(true, forKey: .hasCompletedOnboardingUserDefaultsKey)

      defaultLogger.record(
        event: "onboarding_completed",
        value: "success",
        metadata: [
          "accessibility_granted": String(isAccessibilityPermissionGranted),
          "xcode_extension_granted": String(isXcodeExtensionPermissionGranted),
        ])

      onDone()
    }
    currentStep = getStep()
  }

  func skipAllRemainingSteps() {
    currentStep = .setupComplete
  }

  func handleRequestAccessibilityPermission() {
    permissionsService.request(permission: .accessibility)
  }

  func handleRequestXcodeExtensionPermission() {
    permissionsService.request(permission: .xcodeExtension)
  }

  private let onDone: @MainActor () -> Void
  /// Bring the onboarding window to the front (when opening the settings, it'll be behind the settings window).
  private let bringWindowToFront: @MainActor () -> Void

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  /// Skips the Xcode extension permission step, either because they are granted or ignored.
  private var skipXcodeExtension = false

  private let userDefaults: UserDefaultsI
  private let settingsService: SettingsService
  private let permissionsService: PermissionsService
  private var hasSkippedWelcomeScreen = false

  private func getStep() -> OnboardingStep {
    if !hasSkippedWelcomeScreen {
      return .welcome
    }
    if permissionsService.status(for: .accessibility).currentValue == false {
      return .accessibilityPermission
    }
    if permissionsService.status(for: .xcodeExtension).currentValue == false, !skipXcodeExtension {
      return .xcodeExtensionPermission
    }
    if !hasSkippedProviderSetup, !canSkipProviderSetup {
      return .providersSetup
    }
    return .setupComplete
  }

}

#if DEBUG
/// Used for previews
extension OnboardingViewModel {
  convenience init() {
    self.init(bringWindowToFront: { }, onDone: { })
  }
}
#endif
