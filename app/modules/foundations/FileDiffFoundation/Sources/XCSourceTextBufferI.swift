// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// MARK: - XCSourceTextBufferI

/// A protocol similar to `XCSourceTextBuffer` that allows for mocking for tests,
/// and provides a more Swift friendly API.
public protocol XCSourceTextBufferI {
  var completeBuffer: String { get }

  func insert(line: String, at index: Int)

  func removeLine(at index: Int)

  func line(at index: Int) throws -> String
}
