// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import FoundationInterfaces
import LLMServiceInterface
import LoggingServiceInterface
import Observation
import PermissionsServiceInterface
import SettingsServiceInterface

// MARK: - OnboardingStep

enum OnboardingStep: Equatable, CaseIterable {
  case welcome
  case osPermissions
  case providersSetup
  case autocompletion
  case setupComplete

  var allCases: [OnboardingStep] {
    [.welcome, .osPermissions, .providersSetup, .autocompletion, .setupComplete]
  }

  var index: Int {
    OnboardingStep.allCases.firstIndex(of: self) ?? 0
  }
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
    @Dependency(\.llmService) var llmService
    self.llmService = llmService
    @Dependency(\.permissionsService) var permissionsService
    self.permissionsService = permissionsService
    @Dependency(\.settingsService) var settingsService
    self.settingsService = settingsService

    isAccessibilityPermissionGranted = permissionsService.status(for: .accessibility).currentValue.isGranted
    isXcodeExtensionPermissionGranted = permissionsService.status(for: .xcodeExtension).currentValue.isGranted
    isXcodeAIProviderPermissionGranted = permissionsService.status(for: .xcodeAutomation).currentValue.isGranted
    hasSetupAIProvider = !llmService.activeModels.currentValue.isEmpty
    hasSetupAutocompletionProvider = settingsService.value(for: \.codeCompletionProviderId) != nil

    currentStep = .welcome

    permissionsService.status(for: .accessibility).sink { @Sendable [weak self] status in
      Task { @MainActor in
        guard let self else { return }
        self.isAccessibilityPermissionGranted = status.isGranted
        if status.isGranted, self.currentStep == .osPermissions {
          defaultLogger.record(
            event: "accessibility_permission_granted",
            metadata: [
              "source": "onboarding",
            ])
          self.bringWindowToFront()
        }
      }
    }.store(in: &cancellables)

    permissionsService.status(for: .xcodeExtension).sink { @Sendable [weak self] status in
      Task { @MainActor in
        guard let self else { return }
        self.isXcodeExtensionPermissionGranted = status.isGranted
        if status.isGranted, self.currentStep == .osPermissions {
          defaultLogger.record(
            event: "xcode_extension_permission_granted",
            metadata: [
              "source": "onboarding",
            ])
          self.bringWindowToFront()
        }
      }
    }.store(in: &cancellables)

    permissionsService.status(for: .xcodeAutomation).sink { @Sendable [weak self] status in
      Task { @MainActor in
        guard let self else { return }
        self.isXcodeAIProviderPermissionGranted = status.isGranted
        if status.isGranted, self.currentStep == .osPermissions {
          defaultLogger.record(
            event: "xcode_automation_permission_granted",
            metadata: [
              "source": "onboarding",
            ])
          self.bringWindowToFront()
        }
      }
    }.store(in: &cancellables)

    llmService.activeModels.sink { @Sendable [weak self] models in
      Task { @MainActor in
        guard let self else { return }
        if !models.isEmpty {
          self.hasSetupAIProvider = true
        }
      }
    }.store(in: &cancellables)
  }

  private(set) var isXcodeExtensionPermissionGranted: Bool

  private(set) var isXcodeAIProviderPermissionGranted: Bool

  private(set) var isAccessibilityPermissionGranted: Bool

  private(set) var hasSetupAIProvider: Bool
  private(set) var hasSetupAutocompletionProvider: Bool

  private(set) var hasSkippedProviderSetup = false

  private(set) var currentStep: OnboardingStep

  /// Skips the Xcode extension permission step, either because they are granted or ignored.
  private(set) var hasSkippedXcodeExtension = false
  private(set) var hasSkippedXcodeAIProviderPermissions = false
  private(set) var hasSkippedAutcompletionSetup = false

  var canGoToNextStep: Bool {
    switch currentStep {
    case .welcome:
      true

    case .osPermissions:
      isAccessibilityPermissionGranted && (isXcodeExtensionPermissionGranted || hasSkippedXcodeExtension) &&
        (isXcodeAIProviderPermissionGranted || hasSkippedXcodeAIProviderPermissions)

    case .providersSetup:
      hasSetupAIProvider

    case .autocompletion:
      hasSetupAutocompletionProvider

    case .setupComplete:
      true
    }
  }

  func requestXcodeAIIntegrationPermission() {
    permissionsService.request(permission: .xcodeAutomation)

    settingsService.update(setting: \.automaticallyUpdateXcodeSettings, to: true)
  }

  func handleMoveToNextStep() {
    if currentStep == .welcome {
      hasSkippedWelcomeScreen = true
    }
    if currentStep == .osPermissions {
      hasSkippedXcodeExtension = true
    }
    if currentStep == .providersSetup, hasSetupAIProvider {
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
    if canGoToNextStep {
      currentStep = OnboardingStep.allCases[safe: currentStep.index + 1] ?? .setupComplete
    }
  }

  func handleMoveToPreviousStep() {
    currentStep = OnboardingStep.allCases[safe: currentStep.index - 1] ?? .welcome
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

  func handleSkipXcodeExtensionPermissions() {
    hasSkippedXcodeExtension = true
  }

  func handleSkipXcodeAIProviderPermissions() {
    hasSkippedXcodeAIProviderPermissions = true
  }

  func handleSkipAutocompletionSetup() {
    hasSkippedAutcompletionSetup = true
  }

  private let onDone: @MainActor () -> Void
  /// Bring the onboarding window to the front (when opening the settings, it'll be behind the settings window).
  private let bringWindowToFront: @MainActor () -> Void

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  private let userDefaults: UserDefaultsI
  private let llmService: LLMService
  private let permissionsService: PermissionsService
  private let settingsService: SettingsService
  private var hasSkippedWelcomeScreen = false

}

#if DEBUG
/// Used for previews
extension OnboardingViewModel {
  convenience init() {
    self.init(bringWindowToFront: { }, onDone: { })
  }
}
#endif
