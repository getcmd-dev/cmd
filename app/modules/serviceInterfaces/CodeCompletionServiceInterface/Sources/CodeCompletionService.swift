// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import ConcurrencyFoundation
import FileDiffTypesFoundation
import Foundation
import XcodeObserverServiceInterface

// MARK: - CodeCompletionService

public protocol CodeCompletionService: Sendable {

  /// Whether the code completion service is available for use.
  var isAvailable: ReadonlyCurrentValueSubject<Bool> { get }
  /// Fetches a completion suggestion for the given file content and selection.
  func suggestCompletion(_ request: CompletionRequest)
    async throws -> (cachedRequestId: Int, suggestion: CompletionSuggestion)?

  /// Returns synchronously a cached completion suggestion if available.
  func cachedCompletion(_ request: CompletionRequest)
    throws -> (cachedRequestId: Int, suggestion: CompletionSuggestion?)?

  func deleteCachedCompletion(cachedRequestId: Int)

  /// Logs whether a suggested completion was accepted or rejected by the user.
  func logCompletionAcceptance(suggestion: CompletionSuggestion, accepted: Bool)
}

// MARK: - CompletionRequest

public struct CompletionRequest: Sendable {
  public let workspace: URL
  public let file: URL
  public let content: String
  public let selection: Range
  public let timeout: TimeInterval

  public init(workspace: URL, file: URL, content: String, selection: Range, timeout: TimeInterval) {
    self.workspace = workspace
    self.file = file
    self.content = content
    self.selection = selection
    self.timeout = timeout
  }
}

// MARK: - CompletionSuggestion

public struct CompletionSuggestion: Sendable {
  public init(
    file: URL,
    oldContent: String,
    newContent: String,
    newCursorSelection: Range,
    diffLineStart: Int,
    diff: [LineChange],
    styledOldContent: StyledContentTask? = nil,
    styledNewContent: StyledContentTask? = nil)
  {
    self.file = file
    self.oldContent = oldContent
    self.newContent = newContent
    self.newCursorSelection = newCursorSelection
    self.diffLineStart = diffLineStart
    self.diff = diff
    self.styledOldContent = styledOldContent
    self.styledNewContent = styledNewContent
  }

  public struct LineChange: Sendable {
    public let changes: [WordChange]

    public init(changes: [WordChange]) {
      self.changes = changes
    }

    public typealias WordChange = CharacterLevelChange
  }

  /// A task that produces a syntax-highlighted `AttributedString`.
  /// This is used to cache highlighting work across cache hits.
  public typealias StyledContentTask = Task<AttributedString, Error>

  /// The file for which the completion is suggested
  public let file: URL
  /// The entire old content of the file before applying the suggestion
  public let oldContent: String
  /// The entire new content of the file after applying the suggestion
  public let newContent: String
  /// The cursor selection range in the new content
  public let newCursorSelection: Range
  /// The first line (0-based index) of the diff in the old/new content
  public let diffLineStart: Int
  /// The diff between the old and new content, character by character.
  public let diff: [LineChange]

  /// Cached syntax-highlighted old content (optional, for performance).
  public let styledOldContent: StyledContentTask?
  /// Cached syntax-highlighted new content (optional, for performance).
  public let styledNewContent: StyledContentTask?

}

/// #if DEBUG
extension [CompletionSuggestion.LineChange] {
  public var debugDescription: String {
    map(\.debugDescription).joined(separator: "")
  }
}

extension CompletionSuggestion.LineChange {
  public var debugDescription: String {
    changes.map { change in
      switch change.type {
      case .added:
        "{+\(change.text)+}"
      case .removed:
        "{-\(change.text)-}"
      case .unchanged:
        "\(change.text)"
      }
    }.joined(separator: "")
  }
}

extension CompletionSuggestion.LineChange.WordChange {
  public var debugDescription: String {
    switch type {
    case .added:
      "{+\(text)+}"
    case .removed:
      "{-\(text)-}"
    case .unchanged:
      "\(text)"
    }
  }
}

// #endif
