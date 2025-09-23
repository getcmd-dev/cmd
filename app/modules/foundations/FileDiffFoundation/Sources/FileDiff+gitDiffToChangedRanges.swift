// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffTypesFoundation

extension FileDiff {

  /// Parses a custom diff (of the form shown in the question) and returns
  /// an array of (range, isNew) segments that, if concatenated, produce
  /// the "merged" result (old + new additions).
  ///
  /// When a character is in both the old and new content, the range pointer refers to its position in the new content.
  static func gitDiffToChangedRanges(oldContent: String, newContent: String, diffText: String) -> [LineChange] {
    let newLines = newContent.splitLines()
    let newLinesOffset = offsetFor(lines: newLines)
    let oldLines = oldContent.splitLines()
    let oldLinesOffset = offsetFor(lines: oldLines)

    var result = [LineChange]()
    var removedLines = 0
    var addedLines = 0

    let separator =
      /^@@ -(?<removedLineOffset>\d+)(?:,(?<removedLineCount>\d+))? \+(?<addedLineOffset>\d+)(?:,(?<addedLineCount>\d+))? @@(?<header>.*)\n/
        .anchorsMatchLineEndings()
    let parts = diffText.split(after: separator)

    for (matchOutput, diffContent) in parts {
      guard
        let addedLineOffset = Int(matchOutput.addedLineOffset)
      else {
        assertionFailure("the matched values are not in the expected format")
        continue
      }
      // Add the unchanged content between the diffs
      if result.count - removedLines < addedLineOffset - 1 {
        for i in (result.count - removedLines)..<addedLineOffset - 1 {
          let range = newLinesOffset[i]..<newLinesOffset[i + 1]
          result.append(LineChange(i, range, newLines[i], .unchanged))
        }
      }

      for l in diffContent.splitLines() {
        if l.starts(with: "+") {
          let i = result.count - removedLines
          let range = newLinesOffset[i]..<newLinesOffset[i + 1]
          result.append(LineChange(i, range, newLines[i], .added))
          addedLines += 1
        } else if l.starts(with: "-") {
          let i = result.count - addedLines
          let range = oldLinesOffset[i]..<oldLinesOffset[i + 1]
          result.append(LineChange(i, range, oldLines[i], .removed))
          removedLines += 1
        } else if l.starts(with: " ") {
          let i = result.count - removedLines
          let range = newLinesOffset[i]..<newLinesOffset[i + 1]
          result.append(LineChange(i, range, newLines[i], .unchanged))
        }
      }
    }

    // Add the content after the last diff as unchanged
    while result.count - removedLines < newLines.count {
      let i = result.count - removedLines
      let range = newLinesOffset[i]..<newLinesOffset[i + 1]
      result.append(LineChange(i, range, newLines[i], .unchanged))

      addedLines += 1
    }

    return result
  }

  private static func offsetFor(lines: [String.SubSequence]) -> [Int] {
    var result = [Int]()
    result.reserveCapacity(lines.count + 1)
    var offset = 0
    for l in lines {
      result.append(offset)
      offset += l.count
    }
    result.append(offset)
    return result
  }

}

extension StringProtocol {
  public func substring(_ range: Range<Int>) -> SubSequence {
    self[index(startIndex, offsetBy: range.lowerBound)..<index(startIndex, offsetBy: range.upperBound)]
  }
}

extension StringProtocol where SubSequence == Substring {

  func split<RegexValues>(separatedBy regex: Regex<RegexValues>) -> [(
    previousSeparator: RegexValues?,
    content: SubSequence,
    nextSeparator: RegexValues?)]
  {
    let separatorMatches = matches(of: regex)

    var result: [(previousSeparator: RegexValues?, content: SubSequence, nextSeparator: RegexValues?)] = [
      (nil, self[..<(separatorMatches.first?.range.lowerBound ?? endIndex)], separatorMatches.first?.output),
    ]

    for (idx, match) in separatorMatches.enumerated() {
      let separatedContentStartIndex = match.range.upperBound
      let nextSeparator = separatorMatches[safe: idx + 1]
      let separatedContentEndIndex = nextSeparator?.range.lowerBound ?? endIndex
      let separatedContent = self[separatedContentStartIndex..<separatedContentEndIndex]
      result.append((match.output, separatedContent, nextSeparator?.output))
    }

    return result
  }

  func split<RegexValues>(after regex: Regex<RegexValues>) -> [(previousSeparator: RegexValues, content: SubSequence)] {
    split(separatedBy: regex).compactMap {
      guard let previousSeparator = $0.previousSeparator else { return nil }
      return (previousSeparator, $0.content)
    }
  }
}

extension Collection {
  /// Returns the element at the specified index if it is within bounds, otherwise nil.
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
