// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// MARK: - Position

public struct Position: Codable, Equatable, Sendable, Hashable {
  /// The line offset (0-based index).
  public var line: Int
  /// The character offset (0-based index).
  public var character: Int

  public init(line: Int, character: Int) {
    self.line = line
    self.character = character
  }
}

// MARK: - Selection

public struct Selection: Codable, Equatable, Sendable, Hashable {
  public var start: Position
  public var end: Position

  public init(start: Position, end: Position) {
    self.start = start
    self.end = end
  }
}
