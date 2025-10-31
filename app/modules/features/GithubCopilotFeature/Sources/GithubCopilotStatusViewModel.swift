// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import Dependencies
import GithubCopilotServiceInterface
import Observation

@MainActor @Observable
final class GithubCopilotStatusViewModel: Sendable {
  init() {
    @Dependency(\.githubCopilotService) var githubCopilotService
    self.githubCopilotService = githubCopilotService
    cancellable = githubCopilotService.loginStatus.sink { @Sendable status in
      Task { @MainActor [weak self] in
        guard let self else { return }
        switch status {
        case .loggedIn(user: let username):
          self.username = username
        default:
          username = nil
        }
        authStatus = status
      }
    }
  }

  var cancellable: AnyCancellable?
  var username: String?
  var error: String?
  var signInInfo: SignInInitiateResult?
  var authStatus = LoginStatus.loggedOut

  func startSignIn() async throws {
    signInInfo = try await githubCopilotService.initiateSignIn()
  }

  func confirmSignIn() async throws {
    guard let userCode = signInInfo?.userCode else {
      throw AppError("User code is missing.")
    }
    try await githubCopilotService.confirmSignIn(userCode: userCode)
  }

  func testCompletion() async { }

  func signOut() async throws {
    try await githubCopilotService.signOut()
  }

  private let githubCopilotService: GithubCopilotService
}
