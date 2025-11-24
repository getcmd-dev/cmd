// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import FileDiffFoundation
import Foundation

extension RawCompletionSuggestion {
  func applied(to content: String, file: URL, selection _: Range) -> CodeCompletionServiceInterface.CompletionSuggestion? {
    // Convert the old content to lines for position calculation
    let lines = content.splitLines()
    let lineOffsets = lines.reduce(into: [0], { acc, l in
      acc.append((acc.last ?? 0) + l.count)
    })

    // Validate positions are within bounds
    guard startPosition.line < lines.count, endPosition.line < lines.count else {
      return nil
    }

    // Validate character positions are within line bounds
    guard
      let startLine = lines[safe: startPosition.line], startPosition.character <= startLine.count,
      let endLine = lines[safe: endPosition.line], endPosition.character <= endLine.count
    else {
      return nil
    }

    // Calculate character offset for start and end positions
    let startOffset = lineOffsets[startPosition.line] + startPosition.character
    let endOffset = lineOffsets[endPosition.line] + endPosition.character

    // Apply the completion to get new content
    let beforeCompletion = String(content.prefix(startOffset))
    let afterCompletion = String(content.suffix(from: content.index(content.startIndex, offsetBy: endOffset)))
    let newContent = beforeCompletion + completion + afterCompletion

    // Generate character-level diff
    guard let diffText = try? FileDiff.getCharacterDiff(oldContent: content, newContent: newContent) else {
      return nil
    }
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diffText,
      oldContent: content,
      newContent: newContent)
    guard lineChanges.contains(where: { $0.contains(where: { $0.type != .unchanged }) }) else {
      return nil
    }
    // Convert to CompletionSuggestion format
    let diff = lineChanges.map { lineChanges in
      CodeCompletionServiceInterface.CompletionSuggestion.LineChange(
        changes: lineChanges.map { change in
          CodeCompletionServiceInterface.CompletionSuggestion.LineChange.WordChange(
            text: change.text,
            type: change.type)
        })
    }

    // Calculate new cursor position (at the end of the inserted completion - only the changed part of the completion)
    #if DEBUG
    // Validate the input
    assert(
      lineChanges.trimmingSuffix(while: { $0.allSatisfy({ $0.type == .unchanged }) }).count == lineChanges.count,
      "The last line of a split diff must be unchanged.")
    #endif
    let lastLineTrimmed = lineChanges.last?.trimmingSuffix(while: { $0.type == .unchanged })
    let newCursorCharacter = lastLineTrimmed?.filter { $0.type != .removed }.map(\.text).joined().count ?? 0
    let newCursorLine = firstDiffLine + lineChanges.filter { !$0.allSatisfy({ $0.type == .removed }) }.count - 1
    let newCursorPosition = Position(line: newCursorLine, character: newCursorCharacter)
    let newCursorSelection = Range(start: newCursorPosition, end: newCursorPosition)

    return CodeCompletionServiceInterface.CompletionSuggestion(
      file: file,
      newContent: newContent,
      newCursorSelection: newCursorSelection,
      diffLineStart: firstDiffLine,
      diff: diff)
  }
}
