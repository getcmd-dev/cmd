// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import Observation

@MainActor
final class WindowsView {

  @MainActor
  init(viewModel: WindowsViewModel) {
    self.viewModel = viewModel
    state = viewModel.state

    // handle initial state
    update(
      to: viewModel.state,
      from: .init(
        isSidePanelVisible: false,
        isOnboardingVisible: false))
    startObservations(of: viewModel)
  }

  @MainActor var state: WindowsViewModel.State {
    didSet {
      update(to: state, from: oldValue)
    }
  }

  private let viewModel: WindowsViewModel

  private var sidePanel: SidePanel?
  private var setupWindow: SetupWindow?

  private func update(to newState: WindowsViewModel.State, from oldState: WindowsViewModel.State) {
    if newState.isOnboardingVisible != oldState.isOnboardingVisible {
      if newState.isOnboardingVisible {
        showSetupWindow()
        hideSidePanel()
      } else {
        hideSetupWindow()
        if newState.isSidePanelVisible {
          // The side panel was set to be visible, but this was delayed while the setup view was visible.
          // So we show it now.
          showSidePanel()
        }
      }
    }
    if newState.isSidePanelVisible != oldState.isSidePanelVisible {
      if newState.isSidePanelVisible {
        if newState.isOnboardingVisible == false {
          showSidePanel()
        }
      } else {
        hideSidePanel()
      }
    }
  }

  private func showSidePanel() {
    if sidePanel == nil {
      sidePanel = SidePanel(windowsViewModel: viewModel)
    }

    sidePanel?.show()
    sidePanel?.orderFrontRegardless()
  }

  private func hideSidePanel() {
    sidePanel?.hide()
  }

  private func showSetupWindow() {
    if setupWindow == nil {
      setupWindow = SetupWindow { [weak viewModel] in
        viewModel?.handle(.onboardingDidComplete)
      }
    }
    setupWindow?.setIsVisible(true)
    sidePanel?.orderFrontRegardless()
  }

  private func hideSetupWindow() {
    setupWindow?.setIsVisible(false)
    setupWindow?.close()
  }

  @MainActor
  private func startObservations(of viewModel: WindowsViewModel) {
    withObservationTracking({
      _ = viewModel.state
    }, onChange: {
      Task { @MainActor [weak self] in
        guard let self, viewModel === self.viewModel else { return }
        state = viewModel.state
        startObservations(of: viewModel)
      }
    })
  }

}
