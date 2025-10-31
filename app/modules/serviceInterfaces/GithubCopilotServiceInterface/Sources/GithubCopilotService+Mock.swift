// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockGithubCopilotService: GithubCopilotService {
  public init(id: String = "mock-code-completion-provider") {
    self.id = id
  }

  public var _loginStatus = CurrentValueSubject<LoginStatus, Never>(.loggedOut)
  public var _isLSPServerInstalled = CurrentValueSubject<Bool, Never>(false)

  public let id: String

  public var onProvideCompletion: (@Sendable () async throws -> CompletionSuggestion)?
  public var onDidSave: (@Sendable (URL, String) -> Void)?
  public var onInstallLSPServer: (@Sendable () async throws -> Void)?

  public var onCheckStatus: (@Sendable () async throws -> LoginStatus)?
  public var onInitiateSignIn: (@Sendable () async throws -> SignInInitiationResult)?
  public var onConfirmSignIn: (@Sendable (String) async throws -> Void)?
  public var onSignOut: (@Sendable () async throws -> Void)?

  public var loginStatus: ReadonlyCurrentValueSubject<LoginStatus, Never> {
    _loginStatus.readonly()
  }

  public var isLSPServerInstalled: ReadonlyCurrentValueSubject<Bool, Never> {
    _isLSPServerInstalled.readonly()
  }

  public func provideCompletion() async throws -> CompletionSuggestion {
    guard let onProvideCompletion else {
      throw AppError("No completion provided")
    }
    return try await onProvideCompletion()
  }

  public func didSave(file: URL, content: String) {
    onDidSave?(file, content)
  }

  public func checkStatus() async throws -> LoginStatus {
    guard let onCheckStatus else {
      throw AppError("No login status provided")
    }
    return try await onCheckStatus()
  }

  public func initiateSignIn() async throws -> SignInInitiationResult {
    guard let onInitiateSignIn else {
      throw AppError("No onInitiateSignIn provided")
    }
    return try await onInitiateSignIn()
  }

  public func confirmSignIn(userCode: String) async throws {
    try await onConfirmSignIn?(userCode)
  }

  public func signOut() async throws {
    try await onSignOut?()
  }

  public func installLSPServer() async throws {
    try await onInstallLSPServer?()
  }
}
#endif
