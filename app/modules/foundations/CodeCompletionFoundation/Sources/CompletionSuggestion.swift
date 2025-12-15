// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation

// MARK: - CompletionSuggestion

public struct CompletionSuggestion: Sendable {
  public init(
    file: URL,
    oldContent: String,
    newContent: String,
    newCursorSelection: Selection,
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

  public struct LineChange: Sendable, Hashable {
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
  public let newCursorSelection: Selection
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

extension CompletionSuggestion {
  public init?(
    file: URL,
    oldContent: String,
    newContent: String)
  {
    // Generate character-level diff
    guard let diffText = try? FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent) else {
      return nil
    }
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diffText,
      oldContent: oldContent,
      newContent: newContent)
    guard lineChanges.contains(where: { $0.contains(where: { $0.type != .unchanged }) }) else {
      return nil
    }
    // Convert to CompletionSuggestion format
    let diff = lineChanges.map { lineChanges in
      CompletionSuggestion.LineChange(
        changes: lineChanges.map { change in
          CompletionSuggestion.LineChange.WordChange(
            text: change.text,
            type: change.type)
        })
    }

    // Calculate new cursor position (at the end of the inserted completion - only the changed part of the completion)
    #if DEBUG
    // Validate the input
    assert(
      lineChanges.trimmingSuffix(while: { $0.allSatisfy({ $0.type == .unchanged }) }).count == lineChanges.count,
      "The last line of a split diff must be unchanged.")
    #endif
    let lastLineTrimmed = lineChanges.last?.trimmingSuffix(while: { $0.type == .unchanged })
    let newCursorCharacter = lastLineTrimmed?.filter { $0.type != .removed }.map(\.text).joined().count ?? 0
    let newCursorLine = firstDiffLine + lineChanges.filter { !$0.allSatisfy({ $0.type == .removed }) }.count - 1
    let newCursorPosition = Position(line: newCursorLine, character: newCursorCharacter)
    let newCursorSelection = Selection(start: newCursorPosition, end: newCursorPosition)

    self.init(
      file: file,
      oldContent: oldContent,
      newContent: newContent,
      newCursorSelection: newCursorSelection,
      diffLineStart: firstDiffLine,
      diff: diff)
  }
}
