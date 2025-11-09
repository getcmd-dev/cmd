// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Algorithms
import FileDiffTypesFoundation

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

extension FileDiff {

  /// Parses a character-level git diff (from `git diff --word-diff-regex=.`) and returns
  /// an array of lines, where each line contains grouped character-level changes.
  ///
  /// The git diff format uses {+...+} for additions and [-...-] for removals.
  /// Characters outside these markers are unchanged.
  ///
  /// Adjacent characters of the same type are grouped together into a single `CharacterLevelChange`.
  ///
  /// - Returns: A tuple containing the line changes array and the index (0-based) of the first changed line in the old content.
  public static func characterDiffToLineChanges(
    diff: String)
    -> (lineChanges: [[CharacterLevelChange]], firstChangedLine: Int)
  {
    print("diff", diff)
    var result = [[CharacterLevelChange]]()
    var currentLineChanges = [CharacterLevelChange]()
    var firstChangedLine = 0

    // Parse hunk headers to find the first changed line
    let hunkHeaderPattern = /@@ -(?<oldStart>\d+)/
    if let match = diff.firstMatch(of: hunkHeaderPattern) {
      firstChangedLine = Int(match.output.oldStart) ?? 1
    }
    if firstChangedLine > 0 {
      firstChangedLine -= 1 // 1 to 0 based index
    } else {
      // initial content is empty
    }

    // Skip hunk headers (lines starting with @@)
    let contentLines = diff.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.hasPrefix("@@") }
    let content = contentLines.joined(separator: "\n")

    // Use regex to match the different change types
    // Note: We use lazy matching (.*?) to match content up to the closing sequence
    let additionPattern = /\{\+(?<added>.*?)\+\}/
    let removalPattern = /\[-(?<removed>.*?)-\]/

    var position = content.startIndex

    while position < content.endIndex {
      // Try to match addition
      if let addMatch = content[position...].prefixMatch(of: additionPattern) {
        let addedText = String(addMatch.output.added)
        appendGroupedChanges(text: addedText, type: .added, to: &currentLineChanges, resultLines: &result)
        position = addMatch.range.upperBound
        continue
      }

      // Try to match removal
      if let remMatch = content[position...].prefixMatch(of: removalPattern) {
        let removedText = String(remMatch.output.removed)
        appendGroupedChanges(text: removedText, type: .removed, to: &currentLineChanges, resultLines: &result)
        position = remMatch.range.upperBound
        continue
      }

      // Otherwise it's an unchanged character
      let char = content[position]
      if char == "\n" {
        // If the line contains only added or removed content (no unchanged content),
        // the newline should be part of that change type, not unchanged
        let hasOnlyAddedOrRemoved = !currentLineChanges.isEmpty &&
          currentLineChanges.allSatisfy { $0.type != .unchanged }

        if hasOnlyAddedOrRemoved, let lastChange = currentLineChanges.last {
          // Append newline to the last change (which is added or removed)
          currentLineChanges[currentLineChanges.count - 1] = CharacterLevelChange(
            text: lastChange.text + String(char),
            type: lastChange.type)
        } else {
          // Add newline as unchanged or to existing unchanged group
          if let lastChange = currentLineChanges.last, lastChange.type == .unchanged {
            currentLineChanges[currentLineChanges.count - 1] = CharacterLevelChange(
              text: lastChange.text + String(char),
              type: .unchanged)
          } else {
            currentLineChanges.append(CharacterLevelChange(text: String(char), type: .unchanged))
          }
        }
        result.append(currentLineChanges)
        currentLineChanges = []
      } else {
        // Group consecutive unchanged characters together
        if let lastChange = currentLineChanges.last, lastChange.type == .unchanged {
          currentLineChanges[currentLineChanges.count - 1] = CharacterLevelChange(
            text: lastChange.text + String(char),
            type: .unchanged)
        } else {
          currentLineChanges.append(CharacterLevelChange(text: String(char), type: .unchanged))
        }
      }
      position = content.index(after: position)
    }

    // Append any remaining changes
    if !currentLineChanges.isEmpty {
      result.append(currentLineChanges)
    }

    // Remove context lines that are unchanged.
    let trimmedResult = Array(result.trimming(while: { $0.allSatisfy({ $0.type == .unchanged }) }))
    firstChangedLine += result.prefix(while: { $0.allSatisfy({ $0.type == .unchanged }) }).count
    return (lineChanges: trimmedResult, firstChangedLine: firstChangedLine)
  }

  /// Helper to append text changes, grouping consecutive characters of the same type,
  /// and handling newlines to split into separate result lines.
  private static func appendGroupedChanges(
    text: String,
    type: DiffContentType,
    to currentLineChanges: inout [CharacterLevelChange],
    resultLines: inout [[CharacterLevelChange]])
  {
    var buffer = ""

    for char in text {
      if char == "\n" {
        // Flush current buffer if any
        buffer.append(char)
        if let lastChange = currentLineChanges.last, lastChange.type == type {
          currentLineChanges[currentLineChanges.count - 1] = CharacterLevelChange(
            text: lastChange.text + buffer,
            type: type)
        } else {
          currentLineChanges.append(CharacterLevelChange(text: buffer, type: type))
        }

        // Start new line
        resultLines.append(currentLineChanges)
        currentLineChanges = []
        buffer = ""
      } else {
        buffer.append(char)
      }
    }

    // Flush any remaining buffer
    if !buffer.isEmpty {
      if let lastChange = currentLineChanges.last, lastChange.type == type {
        currentLineChanges[currentLineChanges.count - 1] = CharacterLevelChange(
          text: lastChange.text + buffer,
          type: type)
      } else {
        currentLineChanges.append(CharacterLevelChange(text: buffer, type: type))
      }
    }
  }

}
