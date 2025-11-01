// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CodeCompletionProvider

public protocol CodeCompletionProvider: Sendable {
  /// Provide code completion for a given file content and selection.
  /// Note: the suggestion can start at an offset before the selection's start.
  /// - Parameters:
  /// - workspace: The URL of the workspace within which the file resides.
  /// - file: The URL of the file for which to provide completions.
  /// - content: The full content of the file.
  /// - version: An increasing number representing the version of the file.
  /// - selection: The text selected by the user. Its start and end are equal when there is no selection but a simple cursor location.
  func suggestCompletion(
    workspace: URL,
    file: URL,
    content: String,
    version: Int,
    selection: Range,
    pasteboardContent: String?)
    async throws -> CompletionSuggestion?
  /// A unique identifier for the provider.
  /// It should remain stable across app updates.
  var id: String { get }
  /// handle a notification that a file has been opened.
  /// - Parameters:
  ///  - workspace: The URL of the workspace within which the file resides.
  ///  - file: The URL of the file that was saved.
  ///  - content: The content of the file when it was opened.
  ///  - version: An increasing number representing the version of the file.
  func didOpen(workspace: URL, file: URL, content: String, version: Int)
  /// handle a notification that a file has been changed.
  /// - Parameters:
  ///  - workspace: The URL of the workspace within which the file resides.
  ///  - file: The URL of the file that was saved.
  ///  - content: The content of the file after it was changed.
  ///  - version: An increasing number representing the version of the file.
  func didChange(workspace: URL, file: URL, content: String, version: Int)
  /// handle a notification that a file has been saved.
  /// - Parameters:
  ///  - workspace: The URL of the workspace within which the file resides.
  ///  - file: The URL of the file that was saved.
  ///  - content: The content of the file when it was saved.
  ///  - version: An increasing number representing the version of the file.
  func didSave(workspace: URL, file: URL, content: String, version: Int)
  /// handle a notification that a file has been closed.
  /// - Parameters:
  ///  - workspace: The URL of the workspace within which the file resides.
  ///  - file: The URL of the file that was saved.
  ///  - content: The content of the file when it was closed.
  ///  - version: An increasing number representing the version of the file.
  func didClose(workspace: URL, file: URL, content: String, version: Int)
}

// MARK: - CodeCompletionProvidersPluginProviding

public protocol CodeCompletionProvidersPluginProviding {
  var codeCompletionProviders: [any CodeCompletionProvider] { get }
}
