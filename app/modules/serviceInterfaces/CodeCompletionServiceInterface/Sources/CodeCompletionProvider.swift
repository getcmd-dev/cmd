// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import Foundation
import SharedValuesFoundation

// MARK: - CodeCompletionProvider

public protocol CodeCompletionProvider: Sendable {
  /// Provide code completion for a given file content and selection.
  /// Note: the suggestion can start at an offset before the selection's start.
  /// - Parameters:
  /// - workspace: The workspace within which the file resides.
  /// - file: The URL of the file for which to provide completions.
  /// - content: The full content of the file.
  /// - version: An increasing number representing the version of the file.
  /// - selection: The text selected by the user. Its start and end are equal when there is no selection but a simple cursor location.
  /// - formattingMetadata: Optional formatting metadata (tab size, indent size, etc.) for the file.
  func suggestCompletion(
    workspace: Workspace,
    file: URL,
    content: String,
    version: Int,
    selection: Range,
    pasteboardContent: String?,
    formattingMetadata: FileFormattingMetadata?)
    async throws -> RawCompletionSuggestion?
  /// A unique identifier for the provider.
  /// It should remain stable across app updates.
  var id: String { get }
  /// A user-friendly name for the provider.
  var displayName: String { get }
  /// Whether the provider is currently available/setup.
  var isAvailable: Bool { get }

  func setUp(workspace: Workspace)

  func close(workspace: URL)

  /// Handle a notification that a file has been opened.
  /// - Parameters:
  ///  - workspace: The workspace within which the file resides.
  ///  - file: The URL of the file that was saved.
  ///  - content: The content of the file when it was opened.
  ///  - version: An increasing number representing the version of the file.
  func didOpen(workspace: Workspace, file: URL, content: String, version: Int)
  /// Handle a notification that a file has been changed.
  /// - Parameters:
  ///  - workspace: The workspace within which the file resides.
  ///  - file: The URL of the file that was saved.
  ///  - content: The content of the file after it was changed.
  ///  - version: An increasing number representing the version of the file.
  func didChange(workspace: Workspace, file: URL, content: String, version: Int)
  /// Handle a notification that a file has been saved.
  /// - Parameters:
  ///  - workspace: The workspace within which the file resides.
  ///  - file: The URL of the file that was saved.
  ///  - content: The content of the file when it was saved.
  ///  - version: An increasing number representing the version of the file.
  func didSave(workspace: Workspace, file: URL, content: String, version: Int)
  /// Handle a notification that a file has been closed.
  /// - Parameters:
  ///  - workspace: The workspace within which the file resides.
  ///  - file: The URL of the file that was saved.
  ///  - content: The content of the file when it was closed.
  ///  - version: An increasing number representing the version of the file.
  func didClose(workspace: Workspace, file: URL, content: String, version: Int)
  /// Handle a notification that a file has been deleted.
  /// - Parameters:
  ///  - workspace: The workspace within which the file resides.
  ///  - file: The URL of the file that was deleted.
  func didDelete(workspace: Workspace, file: URL)
}

// MARK: - Workspace

/// Represents a workspace with its files.
public protocol Workspace: Sendable {
  /// The files currently tracked in the workspace
  var files: [URL] { get }
  /// The URL of the workspace
  var url: URL { get }
  /// The URL of the workspace
  var root: URL { get }
}

// MARK: - FrozenWorkspace

public struct FrozenWorkspace: Workspace {
  public let url: URL
  public let root: URL
  public let files: [URL]

  public init(url: URL, root: URL, files: [URL]) {
    self.url = url
    self.files = files
    self.root = root
  }
}
