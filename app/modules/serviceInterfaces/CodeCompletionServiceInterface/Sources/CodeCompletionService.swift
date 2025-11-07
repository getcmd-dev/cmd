// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import FileDiffTypesFoundation
import Foundation
import XcodeObserverServiceInterface

// MARK: - CodeCompletionService

public protocol CodeCompletionService: Sendable {

  /// Whether the code completion service is available for use.
  var isAvailable: Bool { get }

  func suggestCompletion(
    workspace: URL,
    file: URL,
    content: String,
    selection: Range,
    timeout: TimeInterval)
    async throws -> CompletionSuggestion?

  func logCompletionAcceptance(suggestion: CompletionSuggestion, accepted: Bool)
}

// MARK: - CompletionSuggestion

public struct CompletionSuggestion: Sendable {
  public init(file: URL, newContent: String, newCursorSelection: Range, diffLineStart: Int, diff: [LineChange]) {
    self.file = file
    self.newContent = newContent
    self.newCursorSelection = newCursorSelection
    self.diffLineStart = diffLineStart
    self.diff = diff
  }

  public struct LineChange: Sendable {
    public let changes: [WordChange]

    public init(changes: [WordChange]) {
      self.changes = changes
    }

    public struct WordChange: Sendable {
      public let text: String
      public let type: DiffContentType

      public init(text: String, type: DiffContentType) {
        self.text = text
        self.type = type
      }
    }
  }

  /// The file for which the completion is suggested
  public let file: URL
  /// The entire new content of the file after applying the suggestion
  public let newContent: String
  /// The cursor selection range in the new content
  public let newCursorSelection: Range
  /// The first line (1-based index) of the diff in the old/new content
  public let diffLineStart: Int
  /// The diff between the old and new content, character by character.
  public let diff: [LineChange]

}

#if DEBUG
extension [CompletionSuggestion.LineChange] {
  public var debugDescription: String {
    self.map { $0.changes.map { change in
      switch change.type {
      case .added:
        "{+\(change.text)+}"
      case .removed:
        "{-\(change.text)-}"
      case .unchanged:
        "\(change.text)"
      }
    }.joined(separator: "")
    }.joined(separator: "")
  }
}
#endif
