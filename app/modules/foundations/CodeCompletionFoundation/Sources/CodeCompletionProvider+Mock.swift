// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import Foundation
import SharedValuesFoundation
import ThreadSafe

#if DEBUG

@ThreadSafe
public final class MockCodeCompletionProvider: CodeCompletionProvider {
  public init(id: String = "mock-code-completion-provider") {
    self.id = id

    onSetUp = { _ in }
    onClose = { _ in }
    onDidSave = { _, _, _, _ in }
    onDidOpen = { _, _, _, _ in }
    onDidChange = { _, _, _, _ in }
    onDidClose = { _, _, _, _ in }
    onDidDelete = { _, _ in }
  }

  public let id: String

  public var onSetUp: @Sendable (Workspace) -> Void
  public var onClose: @Sendable (URL) -> Void
  public var onSuggestCompletion: (@Sendable (URL, URL, String, Int, Range, String?, FileFormattingMetadata?) async throws
    -> CompletionSuggestion?)?
  public var onDidSave: @Sendable (URL, URL, String, Int) -> Void
  public var onDidOpen: @Sendable (URL, URL, String, Int) -> Void
  public var onDidChange: @Sendable (URL, URL, String, Int) -> Void
  public var onDidClose: @Sendable (URL, URL, String, Int) -> Void
  public var onDidDelete: @Sendable (URL, URL) -> Void

  public func setUp(workspace: Workspace) {
    onSetUp(workspace)
  }

  public func close(workspace: URL) {
    onClose(workspace)
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
    guard let onSuggestCompletion else {
      throw AppError("No completion provided")
    }
    return try await onSuggestCompletion(workspace, file, content, version, selection, pasteboardContent, formattingMetadata)
  }

  public func didSave(workspace: URL, file: URL, content: String, version: Int) {
    onDidSave(workspace, file, content, version)
  }

  public func didOpen(workspace: URL, file: URL, content: String, version: Int) {
    onDidOpen(workspace, file, content, version)
  }

  public func didChange(workspace: URL, file: URL, content: String, version: Int) {
    onDidChange(workspace, file, content, version)
  }

  public func didClose(workspace: URL, file: URL, content: String, version: Int) {
    onDidClose(workspace, file, content, version)
  }

  public func didDelete(workspace: URL, file: URL) {
    onDidDelete(workspace, file)
  }
}
#endif
