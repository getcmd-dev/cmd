// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CompletionSuggestion

public struct CompletionSuggestion: Sendable {
  public let file: URL
  /// The position where the completion starts (inclusive) in the old content.
  public let startPosition: Position
  /// The position where the completion ends (exclusive) in the old content.
  public let endPosition: Position
  public let completion: String
  public let id: UUID

  public init(file: URL, startPosition: Position, endPosition: Position, completion: String, id: UUID) {
    self.file = file
    self.startPosition = startPosition
    self.endPosition = endPosition
    self.completion = completion
    self.id = id
  }
}
