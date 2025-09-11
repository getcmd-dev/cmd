// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppKit
import ChatAppEvents
import ChatFeature
import Combine
import Dependencies
import FoundationInterfaces
import Observation
import Onboarding
import PermissionsServiceInterface
import XcodeObserverServiceInterface

// MARK: - WindowsViewModel

@Observable @MainActor
final class WindowsViewModel {

  init() {
    state = .init(isSidePanelVisible: false, isOnboardingVisible: false)
    // Initialize the chat VM before displaying as it can be used without being visible.
    // For instance to respond to chat completion requests by an external client.
    chat = ChatViewModel()

    appEventHandlerRegistry.registerHandler { [weak self] event in
      await self?.handle(appEvent: event) ?? false
    }
    permissionsService.status(for: .accessibility).sink { [weak self] isGranted in
      self?.handle(.accessibilityPermissionChanged(isGranted: isGranted))
    }.store(in: &cancellables)
  }

  struct State {
    let isSidePanelVisible: Bool
    let isOnboardingVisible: Bool

    func with(
      isSidePanelVisible: Bool? = nil,
      isOnboardingVisible: Bool? = nil)
      -> State
    {
      State(
        isSidePanelVisible: isSidePanelVisible ?? self.isSidePanelVisible,
        isOnboardingVisible: isOnboardingVisible ?? self.isOnboardingVisible)
    }
  }

  enum WindowsAction {
    case onboardingDidComplete
    case showApplication
    case closeSidePanel
    case accessibilityPermissionChanged(isGranted: Bool?)
  }

  private(set) var state: State
  let chat: ChatViewModel

  /// Whether the onboarding should be visible.
  var isOnboardingVisible: Bool {
    if userDefaults.bool(forKey: .hasCompletedOnboardingUserDefaultsKey) != true {
      // Show onboarding at least once
      return true
    }
    if !isAccessibilityPermissionGranted {
      // Show onboarding if accessibility permission is not granted
      return true
    }
    // If we want to show the onboarding in other conditions, we can add this logic here.
    return false
  }

  func handle(_ action: WindowsAction) {
    switch action {
    case .showApplication:
      state = state.with(isSidePanelVisible: true)

    case .closeSidePanel:
      state = state.with(isSidePanelVisible: false)

    case .accessibilityPermissionChanged(let isGranted):
      guard let isGranted else { return }

      isAccessibilityPermissionGranted = isGranted
      state = state.with(isOnboardingVisible: isOnboardingVisible)

    case .onboardingDidComplete:
      state = state.with(isSidePanelVisible: true, isOnboardingVisible: false)
    }
  }

  @ObservationIgnored
  @Dependency(\.appEventHandlerRegistry) private var appEventHandlerRegistry
  @ObservationIgnored
  @Dependency(\.permissionsService) private var permissionsService
  @ObservationIgnored
  @Dependency(\.userDefaults) private var userDefaults

  @ObservationIgnored private var isAccessibilityPermissionGranted = true // default to true for initial state
  private var cancellables = Set<AnyCancellable>()

  private func handle(appEvent: AppEvent) -> Bool {
    if appEvent is AddCodeToChatEvent {
      handle(.showApplication)
      // Return false here to allow for other consumers to react to the event,
      // for instance to add code to the chat
      return false
    } else if appEvent is HideChatEvent {
      handle(.closeSidePanel)
      // TODO: reset Xcode position
    }
    return false
  }

}
