// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import ConcurrencyFoundation

// MARK: - GithubCopilotService

public protocol GithubCopilotService: CodeCompletionProvider {
  /// Download and install the LSP server for GitHub Copilot
  func installLSPServer() async throws
  /// Check the authentication status for the user
  func checkStatus() async throws -> LoginStatus
  /// Start the sign-in process for GitHub Copilot
  func initiateSignIn() async throws -> SignInInitiationResult
  func confirmSignIn(userCode: String) async throws
  /// Sign out the current user
  func signOut() async throws
  /// Whether the LSP server is installed
  var isLSPServerInstalled: ReadonlyCurrentValueSubject<Bool, Never> { get }
  /// The current login status
  var loginStatus: ReadonlyCurrentValueSubject<LoginStatus, Never> { get }
}

// MARK: - LoginStatus

public enum LoginStatus: Sendable {
  case loggedOut
  case loggingIn
  case loggedIn(user: String)
}

// MARK: - SignInInitiationResult

public struct SignInInitiationResult: Sendable, Codable {
  public let status: SignInInitiateStatus
  public let userCode: String
  public let verificationUri: String
  public let expiresIn: Int?
  public let interval: Int?

  public init(status: SignInInitiateStatus, userCode: String, verificationUri: String, expiresIn: Int?, interval: Int?) {
    self.status = status
    self.userCode = userCode
    self.verificationUri = verificationUri
    self.expiresIn = expiresIn
    self.interval = interval
  }
}

// MARK: - GithubCopilotServiceProviding

public protocol GithubCopilotServiceProviding {
  var githubCopilotService: GithubCopilotService { get }
}

// MARK: - SignInInitiateStatus

public enum SignInInitiateStatus: String, Codable, Sendable {
  case promptUserDeviceFlow = "PromptUserDeviceFlow"
  case alreadySignedIn = "AlreadySignedIn"
}
