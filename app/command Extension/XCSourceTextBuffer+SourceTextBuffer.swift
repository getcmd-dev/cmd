// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import XcodeKit

// MARK: - XCSourceTextBuffer + XCSourceTextBufferI

extension XCSourceTextBuffer: @retroactive XCSourceTextBufferI {
  public func insert(line: String, at index: Int) {
    lines.insert(line, at: index)
  }

  public func removeLine(at index: Int) {
    lines.removeObject(at: index)
  }

  public func line(at index: Int) throws -> String {
    // Provide detailed error information for debugging
    guard index >= 0 else {
      throw NSError(
        domain: "XCSourceTextBuffer",
        code: 0,
        userInfo: [
          NSLocalizedDescriptionKey: "Index \(index) is negative. Buffer has \(lines.count) lines.",
        ])
    }

    guard index < lines.count else {
      throw NSError(
        domain: "XCSourceTextBuffer",
        code: 0,
        userInfo: [
          NSLocalizedDescriptionKey: "Index \(index) out of bounds. Buffer has \(lines.count) lines (valid range: 0..\(lines.count - 1)). Last line: \(lines[lines.count - 1])",
        ])
    }

    guard let line = lines[index] as? String else {
      let actualType = type(of: lines[index])
      throw NSError(
        domain: "XCSourceTextBuffer",
        code: 0,
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to cast line at index \(index) to String. Actual type: \(actualType). Buffer has \(lines.count) lines.",
        ])
    }

    return line
  }
}
