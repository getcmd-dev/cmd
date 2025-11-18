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

    let loginStatus = githubCopilotService.loginStatus
    authStatus = loginStatus.currentValue
    let isLSPServerInstalled = githubCopilotService.isLSPServerInstalled
    self.isLSPServerInstalled = isLSPServerInstalled.currentValue

    loginStatus.sink { @Sendable status in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if authStatus != status {
          error = nil
          signInInfo = nil
          authStatus = status
        }
      }
    }.store(in: &cancellables)

    githubCopilotService.isLSPServerInstalled.sink { @Sendable isInstalled in
      Task { @MainActor [weak self] in
        self?.isLSPServerInstalled = isInstalled
      }
    }.store(in: &cancellables)
  }

  #if DEBUG
  init(
    isLSPServerInstalled: Bool,
    authStatus: LoginStatus,
    error: String? = nil,
    signInInfo: SignInInitiationResult? = nil,
    isInstallingLSPServer: Bool = false)
  {
    @Dependency(\.githubCopilotService) var githubCopilotService
    self.githubCopilotService = githubCopilotService
    self.isLSPServerInstalled = isLSPServerInstalled
    self.authStatus = authStatus
    self.error = error
    self.signInInfo = signInInfo
    self.isInstallingLSPServer = isInstallingLSPServer
  }
  #endif

  private(set) var isLSPServerInstalled: Bool
  private(set) var error: String?
  private(set) var signInInfo: SignInInitiationResult?
  private(set) var authStatus: LoginStatus
  private(set) var isInstallingLSPServer = false

  var username: String? {
    switch authStatus {
    case .loggedIn(user: let username):
      username
    default:
      nil
    }
  }

  func startSignIn() async throws {
    signInInfo = try await githubCopilotService.initiateSignIn()
  }

  func installLSPServer() async throws {
    guard !isInstallingLSPServer else { return }
    isInstallingLSPServer = true
    defer { isInstallingLSPServer = false }

    try await githubCopilotService.installLSPServer()
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

  private var cancellables = Set<AnyCancellable>()

  private let githubCopilotService: GithubCopilotService
}
