// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import FileDiffTypesFoundation
import Foundation
import LoggingServiceInterface

// MARK: - SourceModificationHelpers

public enum SourceModificationHelpers {
  public static func update(buffer: XCSourceTextBufferI, with fileChange: FileDiffTypesFoundation.FileChange) throws {
    try applyEdit(buffer: buffer, fileChange: fileChange)
  }

  /// Applies an edit to the buffer (handles both full file edits and partial edits)
  private static func applyEdit(buffer: XCSourceTextBufferI, fileChange: FileDiffTypesFoundation.FileChange) throws {
    let selections = buffer.getSelections()
    buffer.removeSelections()

    // Collect lines to remove and lines to add
    // Using ContiguousArray for better performance with value types (small arrays <100 elements)
    var linesToRemove = ContiguousArray<Int>()
    var linesToAdd = ContiguousArray<(lineNumber: Int, content: String)>()

    // Reserve capacity upfront since we know the maximum size
    linesToRemove.reserveCapacity(fileChange.selectedChange.count)
    linesToAdd.reserveCapacity(fileChange.selectedChange.count)

    // Validate and collect changes
    for lineChange in fileChange.selectedChange {
      switch lineChange {
      case .removed(let oldLine, _, let content):
        // Validate that the line to be removed matches what we expect
        let actualLine: String
        do {
          actualLine = try buffer.line(at: oldLine)
        } catch {
          defaultLogger.error("Failed to read line \(oldLine) from buffer for removal validation: \(error.localizedDescription)")
          throw AppError(message: "Failed to read line \(oldLine) from buffer: \(error.localizedDescription)")
        }

        // Cache trimmed values to avoid redundant trimming
        let trimmedActualLine = actualLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExpectedLine = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedActualLine != trimmedExpectedLine {
          defaultLogger
            .error("Line \(oldLine) content mismatch. Expected: '\(trimmedExpectedLine)', Actual: '\(trimmedActualLine)'")
          throw AppError(
            message: "Line \(oldLine) content does not match expected content for removal. Expected: '\(trimmedExpectedLine)', Actual: '\(trimmedActualLine)'")
        }
        linesToRemove.append(oldLine)

      case .added(let newLine, _, let content):
        linesToAdd.append((newLine, content))

      case .unchanged(let oldLine, _, _, let content):
        // For unchanged lines, verify they match
        let actualLine: String
        do {
          actualLine = try buffer.line(at: oldLine)
        } catch {
          defaultLogger
            .error("Failed to read line \(oldLine) from buffer for unchanged validation: \(error.localizedDescription)")
          throw AppError(message: "Failed to read line \(oldLine) from buffer: \(error.localizedDescription)")
        }

        // Cache trimmed values to avoid redundant trimming
        let trimmedActualLine = actualLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExpectedLine = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedActualLine != trimmedExpectedLine {
          defaultLogger
            .error(
              "Unchanged line \(oldLine) content mismatch. Expected: '\(trimmedExpectedLine)', Actual: '\(trimmedActualLine)'")
          throw AppError(
            message: "Unchanged line \(oldLine) content does not match buffer content. Expected: '\(trimmedExpectedLine)', Actual: '\(trimmedActualLine)'")
        }
      }
    }

    // First, remove all lines in reverse order (from bottom to top) to avoid index shifting
    // Sort in-place for better performance
    linesToRemove.sort(by: >)
    for lineNum in linesToRemove {
      buffer.removeLine(at: lineNum)
    }

    linesToAdd.sort(by: { $0.lineNumber < $1.lineNumber })
    for (lineNum, content) in linesToAdd {
      buffer.insert(line: content, at: lineNum)
    }

    guard let newSelections = fileChange.newSelections else {
      // Restore original selections if no new selections provided
      buffer.set(selections: selections)
      return
    }
    buffer.set(selections: newSelections)
  }

}

extension Array {
  func at(_ index: Int) throws -> Element {
    guard index >= 0, index < count else {
      throw AppError(message: "Index \(index) out of bounds [0, \(count) [")
    }
    return self[index]
  }
}

extension String.SubSequence {
  /// Splits the collection into substrings that each represent a line of text.
  public func splitLines()
    -> [String.SubSequence]
  {
    var result = [String.SubSequence]()
    var lineStart = startIndex
    var index = startIndex
    while index < endIndex {
      if self[index] == "\n" {
        result.append(self[lineStart...index])
        lineStart = self.index(after: index)
      }
      index = self.index(after: index)
    }
    if lineStart != endIndex {
      result.append(self[lineStart...])
    }
    return result
  }
}

extension String {
  public func splitLines() -> [String.SubSequence] {
    self[...].splitLines()
  }
}
