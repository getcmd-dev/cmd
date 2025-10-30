// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation

// MARK: - LoginStatus

enum LoginStatus {
  case loggedOut
  case loggingIn
  case loggedIn(user: String)
}

extension GithubCopilotService {

  var loginStatus: ReadonlyCurrentValueSubject<LoginStatus, Never> {
    _loginStatus.readonly()
  }

  func checkStatus() async throws -> LoginStatus {
    let authServer = try await authServer.value
    try await authServer.didInitialize.value

    print("🔐 Checking authentication status...")
    // Send empty object {} as params (required by Copilot LSP)
    let emptyParams = [String: String]()
    let resultData = try await authServer.sendRequest("checkStatus", params: emptyParams)
    let decoder = JSONDecoder()
    let result = try decoder.decode(CheckStatusResult.self, from: resultData)
    print("🔐 Status: \(result.status.rawValue), User: \(result.user ?? "none")")

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

  func initiateSignIn() async throws -> SignInInitiateResult {
    let authServer = try await authServer.value
    try await authServer.didInitialize.value

    print("🔐 Initiating sign in...")
    // Send empty object {} as params (required by Copilot LSP)
    let emptyParams = [String: String]()
    let resultData = try await authServer.sendRequest("signInInitiate", params: emptyParams)
    let decoder = JSONDecoder()
    let result = try decoder.decode(SignInInitiateResult.self, from: resultData)

    if let userCode = result.userCode, let verificationUri = result.verificationUri {
      print("🔐 Sign in at: \(verificationUri)")
      print("🔐 Enter code: \(userCode)")
    }

    return result
  }

  func confirmSignIn(userCode: String) async throws {
    let authServer = try await authServer.value
    try await authServer.didInitialize.value

    print("🔐 Confirming sign in...")
    let params = SignInConfirmParams(userCode: userCode)
    let resultData = try await authServer.sendRequest("signInConfirm", params: params)
    let decoder = JSONDecoder()
    let result = try decoder.decode(SignInConfirmResult.self, from: resultData)
    print("🔐 Sign in result: \(result.status.rawValue), User: \(result.user ?? "none")")

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
    try await authServer.didInitialize.value

    print("🔐 Signing out...")
    // Send empty object {} as params (required by Copilot LSP)
    let emptyParams = [String: String]()
    _ = try await authServer.sendRequest("signOut", params: emptyParams)
    print("🔐 Signed out")
    _loginStatus.send(.loggedOut)
  }
}
