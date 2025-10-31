// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation
import GithubCopilotServiceInterface
import LoggingServiceInterface

// MARK: - LoginStatus

extension DefaultGithubCopilotService {

  var loginStatus: ReadonlyCurrentValueSubject<LoginStatus, Never> {
    _loginStatus.readonly()
  }

  func checkStatus() async throws -> LoginStatus {
    let authServer = try await authServer.value
    // Send empty object {} as params (required by Copilot LSP)
    let result: CheckStatusResult = try await authServer.sendRequest("checkStatus", params: .object([:]))

    let loginStatus: LoginStatus =
      switch (result.status, result.user) {
      case (.alreadySignedIn, .some(let user)):
        .loggedIn(user: user)
      case (.ok, .some(let user)):
        .loggedIn(user: user)
      default:
        .loggedOut
      }

    _loginStatus.send(loginStatus)
    return loginStatus
  }

  func initiateSignIn() async throws -> SignInInitiationResult {
    let authServer = try await authServer.value

    // Send empty object {} as params (required by Copilot LSP)
    return try await authServer.sendRequest("signInInitiate", params: .object([:]))
  }

  func confirmSignIn(userCode: String) async throws {
    let authServer = try await authServer.value

    let params = SignInConfirmParams(userCode: userCode)
    let result: SignInConfirmResult = try await authServer.sendRequest("signInConfirm", params: .init(encoding: params))

    let loginStatus: LoginStatus =
      switch (result.status, result.user) {
      case (.alreadySignedIn, .some(let user)):
        .loggedIn(user: user)
      case (.ok, .some(let user)):
        .loggedIn(user: user)
      default:
        .loggedOut
      }

    _loginStatus.send(loginStatus)
  }

  func signOut() async throws {
    let authServer = try await authServer.value
    // Send empty object {} as params (required by Copilot LSP)
    _ = try await authServer.sendRawRequest("signOut", params: .object([:]))
    _loginStatus.send(.loggedOut)
  }
}
