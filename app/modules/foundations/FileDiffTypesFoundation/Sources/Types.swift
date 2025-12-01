// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FileChange

public struct FileChange: Codable, Sendable {

  public init(
    filePath: URL,
    oldContent: String,
    suggestedNewContent: String,
    selectedChange: [LineChange],
    newSelections: [TextRange]? = nil,
    id: String = UUID().uuidString)
  {
    self.filePath = filePath
    self.oldContent = oldContent
    self.suggestedNewContent = suggestedNewContent
    self.selectedChange = selectedChange
    self.id = id
    self.newSelections = newSelections
  }

  /// The file path of the file to change.
  public let filePath: URL
  /// The original content of the file.
  public let oldContent: String
  /// The suggested new content of the file. If the user selected only some of the suggested changes, the desired new content might be different.
  public let suggestedNewContent: String
  /// The change to apply, given line by line (remove / keep / add).
  /// Its references (line offset, character range) are relative to the old/new/new content.
  public let selectedChange: [LineChange]
  public let id: String
  /// The new position of the selections after applying the change. If nil, the selections remain unchanged.
  public let newSelections: [TextRange]?
}

// MARK: - DiffContentType

public enum DiffContentType: String, Sendable, Codable {
  /// Content that is only present in the previous version.
  case removed
  /// Content that is only present in the new version.
  case added
  /// Content that is present in both versions.
  case unchanged
}

// MARK: - LineChange

public enum LineChange: Sendable, Codable, Equatable {
  /// Line removed from the old version at the given line number.
  case removed(oldLine: Int, characterRange: Range<Int>, content: String)
  /// Line added in the new version at the given line number.
  case added(newLine: Int, characterRange: Range<Int>, content: String)
  /// Line present in both versions (unchanged context).
  case unchanged(oldLine: Int, newLine: Int, characterRange: Range<Int>, content: String)

  /// The content of the line
  public var content: String {
    switch self {
    case .removed(_, _, let content), .added(_, _, let content), .unchanged(_, _, _, let content):
      content
    }
  }

  /// The character range
  public var characterRange: Range<Int> {
    switch self {
    case .removed(_, let range, _), .added(_, let range, _), .unchanged(_, _, let range, _):
      range
    }
  }

  /// The old line number if this line exists in the old version
  public var oldLineNumber: Int? {
    switch self {
    case .removed(let oldLine, _, _), .unchanged(let oldLine, _, _, _):
      oldLine
    case .added:
      nil
    }
  }

  /// The new line number if this line exists in the new version
  public var newLineNumber: Int? {
    switch self {
    case .added(let newLine, _, _), .unchanged(_, let newLine, _, _):
      newLine
    case .removed:
      nil
    }
  }

  /// The type of change
  public var type: DiffContentType {
    switch self {
    case .added:
      .added
    case .removed:
      .removed
    case .unchanged:
      .unchanged
    }
  }

  /// Whether this line is an addition
  public var isAdded: Bool {
    switch self {
    case .added:
      true
    default:
      false
    }
  }

  /// Whether this line is a removal
  public var isRemoved: Bool {
    switch self {
    case .removed:
      true
    default:
      false
    }
  }

  /// Whether this line is unchanged
  public var isUnchanged: Bool {
    switch self {
    case .unchanged:
      true
    default:
      false
    }
  }

}

// MARK: - TextRange

public struct TextRange: Codable, Sendable {
  public let start: TextPosition
  public let end: TextPosition

  public init(start: TextPosition, end: TextPosition) {
    self.start = start
    self.end = end
  }

  public struct TextPosition: Codable, Sendable {
    public let line: Int
    public let character: Int

    public init(line: Int, character: Int) {
      self.line = line
      self.character = character
    }
  }
}

// MARK: - CharacterLevelChange

/// Represents a character-level change in a diff.
public struct CharacterLevelChange: Sendable {
  public let text: String
  public let type: DiffContentType

  public init(text: String, type: DiffContentType) {
    self.text = text
    self.type = type
  }
}
