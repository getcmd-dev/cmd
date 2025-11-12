// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffTypesFoundation
// MARK: - XCSourceTextBufferI

/// A protocol similar to `XCSourceTextBuffer` that allows for mocking for tests,
/// and provides a more Swift friendly API.
public protocol XCSourceTextBufferI {
  var completeBuffer: String { get }
  /// Inserts a line at the specified index.
  func insert(line: String, at index: Int)
  /// Removes a line at the specified index.
  func removeLine(at index: Int)
  /// Retrieves the line at the specified index.
  func line(at index: Int) throws -> String
  /// Retrieves the current selections in the buffer.
  func getSelections() -> [FileDiffTypesFoundation.TextRange]
  /// Removes all current selections in the buffer.
  func removeSelections()
  /// Sets the current selections in the buffer.
  func set(selections: [FileDiffTypesFoundation.TextRange])
}
