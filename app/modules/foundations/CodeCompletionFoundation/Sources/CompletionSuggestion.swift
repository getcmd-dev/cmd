// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CompletionSuggestion

public struct CompletionSuggestion: Sendable {
  public let file: URL
  public let startPosition: CursorPosition
  public let completion: String
  public let id: UUID

  public init(file: URL, startPosition: CursorPosition, completion: String, id: UUID) {
    self.file = file
    self.startPosition = startPosition
    self.completion = completion
    self.id = id
  }
}

// MARK: - CursorPosition

public struct CursorPosition: Codable, Equatable, Sendable {
  public let line: Int
  public let character: Int

  public init(line: Int, character: Int) {
    self.line = line
    self.character = character
  }
}
