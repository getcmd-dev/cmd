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
  /// When the first change is on a new line, the previous unchanged line is returned, and the `firstDiffLine` is that of the unchanged line.
  public static func characterDiffToLineChanges(
    diff: String,
    oldContent: String,
    newContent: String)
    -> (lineChanges: [[CharacterLevelChange]], firstDiffLine: Int)
  {
    var result = [[CharacterLevelChange]]()
    var currentLineChanges = [CharacterLevelChange]()
    var firstDiffLine = 0
    let oldLines = oldContent.splitLines()
    let oldLinesOffsets = oldLines.reduce(into: [Int]()) { acc, l in acc.append((acc.last ?? 0) + l.count) }
    let newLines = newContent.splitLines()
    let newLinesOffsets = newLines.reduce(into: [Int]()) { acc, l in acc.append((acc.last ?? 0) + l.count) }

    // Parse hunk headers to find the first changed line
    let hunkHeaderPattern = /@@ -(?<oldStart>\d+)/
    if let match = diff.firstMatch(of: hunkHeaderPattern) {
      firstDiffLine = Int(match.output.oldStart) ?? 1
    }
    if firstDiffLine > 0 {
      firstDiffLine -= 1 // 1 to 0 based index
    } else {
      // initial content is empty
    }

    // Skip hunk headers (lines starting with @@)
    let diff = diff
      .split(separator: "\n", omittingEmptySubsequences: false)
      .trimming(while: { $0.hasPrefix("@@") })
      .joined(separator: "\n")

    // Use regex to match the different change types
    // Note: We use lazy matching (.*?) to match content up to the closing sequence
    let additionPattern = /\{\+(?<added>.*?)\+\}/
    let removalPattern = /\[-(?<removed>.*?)-\]/

    var diffPosition = diff.startIndex
    var oldContentPosition = oldContent.safeIndex(oldContent.startIndex, offsetBy: oldLinesOffsets[safe: firstDiffLine - 1] ?? 0)
    var newContentPosition = newContent.safeIndex(newContent.startIndex, offsetBy: newLinesOffsets[safe: firstDiffLine - 1] ?? 0)

    while diffPosition < diff.endIndex {
      // Try to match addition
      if let addMatch = diff[diffPosition...].prefixMatch(of: additionPattern) {
        let addedText = String(addMatch.output.added)
        currentLineChanges.append(.init(text: addedText, type: .added))
        diffPosition = addMatch.range.upperBound
        newContentPosition = newContent.safeIndex(newContentPosition, offsetBy: addedText.count)
        continue
      }

      // Try to match removal
      if let remMatch = diff[diffPosition...].prefixMatch(of: removalPattern) {
        let removedText = String(remMatch.output.removed)
        currentLineChanges.append(.init(text: removedText, type: .removed))
        diffPosition = remMatch.range.upperBound
        oldContentPosition = oldContent.safeIndex(oldContentPosition, offsetBy: removedText.count)
        continue
      }

      let char = diff[diffPosition]
      if char == "\n" {
        // New lines are not clearly attributed by the git diff.
        // We lookup in the compared content to know what type of change we are facing.
        let changeType: DiffContentType
        switch (oldContent[safe: oldContentPosition] == "\n", newContent[safe: newContentPosition] == "\n") {
        case (true, true):
          changeType = .unchanged
        case (false, true):
          changeType = .added
        case (true, false):
          changeType = .removed
        case (false, false):
          assertionFailure("Encountered a newline character that wasn't preceded or followed by a newline in either file")
          continue
        }
        currentLineChanges.append(.init(text: String(char), type: changeType))
        if changeType != .added {
          oldContentPosition = oldContent.safeIndex(after: oldContentPosition)
        }
        if changeType != .removed {
          newContentPosition = newContent.safeIndex(after: newContentPosition)
        }
        diffPosition = diff.index(after: diffPosition)
        result.append(currentLineChanges)
        currentLineChanges = []
      } else {
        currentLineChanges.append(CharacterLevelChange(text: String(char), type: .unchanged))
        diffPosition = diff.index(after: diffPosition)
        oldContentPosition = oldContent.safeIndex(after: oldContentPosition)
        newContentPosition = newContent.safeIndex(after: newContentPosition)
      }
    }
    // Because new lines are not clearly represented in git diff, we need to check whether we're missing a trailing new line.
    switch (
      oldContent[safe: oldContentPosition] == "\n",
      newContent[safe: newContentPosition] == "\n")
    {
    case (true, true):
      break
    case (false, false):
      break
    case (true, false):
      currentLineChanges.append(.init(text: "\n", type: .removed))
    case (false, true):
      currentLineChanges.append(.init(text: "\n", type: .added))
    }

    // Add the last line to the result
    if !currentLineChanges.isEmpty {
      result.append(currentLineChanges)
    }

    // Merge consecutives changes of the same type
    result = result.map { lineChanges in lineChanges.reduce(into: [], { acc, change in
      if let last = acc.last, last.type == change.type {
        acc[acc.count - 1] = CharacterLevelChange(text: last.text + change.text, type: last.type)
      } else {
        acc.append(change)
      }
    }) }

    // Remove context lines that are unchanged.
    let trimmedResult = Array(result.enumerated().trimming(while: { idx, lineChanges in
      lineChanges.allSatisfy({ $0.type == .unchanged }) && (idx == result.count - 1 || result[idx + 1].first?.type == .unchanged)
    }).map(\.element))
    firstDiffLine += result.enumerated().prefix(while: { idx, lineChanges in
      lineChanges.allSatisfy({ $0.type == .unchanged }) && (idx == result.count - 1 || result[idx + 1].first?.type == .unchanged)
    }).count
    return (lineChanges: trimmedResult, firstDiffLine: firstDiffLine)
  }
}

#if DEBUG
extension [CharacterLevelChange] {
  public var debugDescription: String {
    map { change in
      switch change.type {
      case .added:
        "{+\(change.text)+}"
      case .removed:
        "{-\(change.text)-}"
      case .unchanged:
        "\(change.text)"
      }
    }.joined(separator: "")
  }
}
#endif
