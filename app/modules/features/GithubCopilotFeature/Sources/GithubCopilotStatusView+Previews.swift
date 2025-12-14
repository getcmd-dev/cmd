// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import GithubCopilotServiceInterface
import SwiftUI

#if DEBUG

@ViewBuilder @MainActor
func previews(isExpanded: Bool) -> some View {
  let viewModels: [GithubCopilotStatusViewModel] = [
    .previewLSPNotInstalled(),
    .previewInstallingLSP(),
    .previewLoggedOut(),
    .previewLoggingIn(),
    .previewLoggedIn(),
    .previewWithError(),
  ]
  VStack(spacing: 0) {
    ForEach(Array(viewModels.enumerated()), id: \.offset) { _, vm in
      GithubCopilotStatusView(viewModel: vm, isExpanded: isExpanded)
        .padding()
        .background(.background)
      Divider()
    }
  }
}

#Preview("Expanded States") {
  ScrollView {
    VStack {
      previews(isExpanded: true)
    }
  }
  .frame(width: 400, height: 700)
}

#Preview("Collapsed States") {
  ScrollView {
    VStack {
      previews(isExpanded: false)
    }
  }
  .frame(width: 400, height: 700)
}

extension GithubCopilotStatusViewModel {
  static func previewLSPNotInstalled() -> GithubCopilotStatusViewModel {
    GithubCopilotStatusViewModel(
      isLSPServerInstalled: false,
      authStatus: .loggedOut)
  }

  static func previewInstallingLSP() -> GithubCopilotStatusViewModel {
    GithubCopilotStatusViewModel(
      isLSPServerInstalled: false,
      authStatus: .loggedOut,
      isInstallingLSPServer: true)
  }

  static func previewLoggedOut() -> GithubCopilotStatusViewModel {
    GithubCopilotStatusViewModel(
      isLSPServerInstalled: true,
      authStatus: .loggedOut)
  }

  static func previewLoggingIn() -> GithubCopilotStatusViewModel {
    GithubCopilotStatusViewModel(
      isLSPServerInstalled: true,
      authStatus: .loggingIn,
      signInInfo: SignInInitiationResult(
        status: .promptUserDeviceFlow,
        userCode: "ABCD-1234",
        verificationUri: "https://github.com/login/device",
        expiresIn: 900,
        interval: 5))
  }

  static func previewLoggedIn() -> GithubCopilotStatusViewModel {
    GithubCopilotStatusViewModel(
      isLSPServerInstalled: true,
      authStatus: .loggedIn(user: "octocat"))
  }

  static func previewWithError() -> GithubCopilotStatusViewModel {
    GithubCopilotStatusViewModel(
      isLSPServerInstalled: true,
      authStatus: .loggedOut,
      error: "Failed to connect to GitHub Copilot server. Please check your internet connection.")
  }
}

#endif
