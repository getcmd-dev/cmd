// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// MARK: - Position

public struct Position: Codable, Equatable, Sendable {
  public let line: Int
  public let character: Int

  public init(line: Int, character: Int) {
    self.line = line
    self.character = character
  }
}

// MARK: - Range

public struct Range: Codable, Equatable, Sendable {
  public let start: Position
  public let end: Position

  public init(start: Position, end: Position) {
    self.start = start
    self.end = end
  }
}
