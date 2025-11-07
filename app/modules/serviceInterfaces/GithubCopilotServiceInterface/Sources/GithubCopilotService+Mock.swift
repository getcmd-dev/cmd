// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import SharedValuesFoundation
import ThreadSafe

#if DEBUG
@ThreadSafe @dynamicMemberLookup
public final class MockGithubCopilotService: GithubCopilotService {

  public init(id: String = "mock-code-completion-provider") {
    self.id = id
  }

  public var _loginStatus = CurrentValueSubject<LoginStatus, Never>(.loggedOut)
  public var _isLSPServerInstalled = CurrentValueSubject<Bool, Never>(false)

  public let id: String

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

  public func suggestCompletion(
    workspace: URL,
    file: URL,
    content: String,
    version: Int,
    selection: Range,
    pasteboardContent: String?,
    formattingMetadata: FileFormattingMetadata?)
    async throws -> CompletionSuggestion?
  {
    try await codeCompletionProvider.suggestCompletion(
      workspace: workspace,
      file: file,
      content: content,
      version: version,
      selection: selection,
      pasteboardContent: pasteboardContent,
      formattingMetadata: formattingMetadata)
  }

  public subscript<T>(dynamicMember keyPath: WritableKeyPath<MockCodeCompletionProvider, T>) -> T {
    get { codeCompletionProvider[keyPath: keyPath] }
    set { codeCompletionProvider[keyPath: keyPath] = newValue }
  }

  public func setUp(workspace: Workspace) {
    codeCompletionProvider.setUp(workspace: workspace)
  }

  public func close(workspace: URL) {
    codeCompletionProvider.close(workspace: workspace)
  }

  public func didSave(workspace: URL, file: URL, content: String, version: Int) {
    codeCompletionProvider.didSave(workspace: workspace, file: file, content: content, version: version)
  }

  public func didOpen(workspace: URL, file: URL, content: String, version: Int) {
    codeCompletionProvider.didOpen(workspace: workspace, file: file, content: content, version: version)
  }

  public func didChange(workspace: URL, file: URL, content: String, version: Int) {
    codeCompletionProvider.didChange(workspace: workspace, file: file, content: content, version: version)
  }

  public func didClose(workspace: URL, file: URL, content: String, version: Int) {
    codeCompletionProvider.didClose(workspace: workspace, file: file, content: content, version: version)
  }

  public func didDelete(workspace: URL, file: URL) {
    codeCompletionProvider.didDelete(workspace: workspace, file: file)
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

  private var codeCompletionProvider = MockCodeCompletionProvider()

}
#endif
