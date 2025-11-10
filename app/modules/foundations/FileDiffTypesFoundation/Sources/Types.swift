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
    id: String = UUID().uuidString)
  {
    self.filePath = filePath
    self.oldContent = oldContent
    self.suggestedNewContent = suggestedNewContent
    self.selectedChange = selectedChange
    self.id = id
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

}

// MARK: - LineOffset

public enum LineOffset: Sendable, Codable, Equatable {
  /// Line is only present in the old version (removed).
  case oldLineOffset(Int)
  /// Line is only present in the new version (added).
  case newLineOffset(Int)
  /// Line is present in both versions.
  case both(old: Int, new: Int)

  /// Returns the old line number if available, or nil if this is a new line only.
  public var oldLineNumber: Int? {
    switch self {
    case .oldLineOffset(let line):
      line
    case .both(old: let line, new: _):
      line
    case .newLineOffset:
      nil
    }
  }

  /// Returns the new line number if available, or nil if this is a removed line only.
  public var newLineNumber: Int? {
    switch self {
    case .newLineOffset(let line):
      line
    case .both(old: _, new: let line):
      line
    case .oldLineOffset:
      nil
    }
  }
}

// MARK: - DiffContentType

public enum DiffContentType: String, Sendable, Codable {
  /// Content that is only present in the previous version.
  case removed
  /// Content that is only present in the new version.
  case added
  /// Content that is present in both versions. The range points to its location in the new version.
  case unchanged
}

// MARK: - LineChange

public struct LineChange: Sendable, Codable {
  public let characterRange: Range<Int>
  /// The line number where the change is located.
  public let lineOffset: LineOffset
  public let content: String
  public let type: DiffContentType

  public init(_ lineOffset: LineOffset, _ characterRange: Range<Int>, _ content: String, _ type: DiffContentType) {
    self.lineOffset = lineOffset
    self.characterRange = characterRange
    self.content = content
    self.type = type
  }

  public init(_ lineOffset: LineOffset, _ characterRange: Range<Int>, _ content: String.SubSequence, _ type: DiffContentType) {
    self.lineOffset = lineOffset
    self.characterRange = characterRange
    self.content = String(content)
    self.type = type
  }
}
