// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import FileDiffFoundation
import Foundation

extension CodeCompletionFoundation.CompletionSuggestion {
  func applied(to content: String, file: URL, selection _: Range) -> CodeCompletionServiceInterface.CompletionSuggestion? {
    // Convert the old content to lines for position calculation
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    // Validate positions are within bounds
    guard startPosition.line < lines.count, endPosition.line < lines.count else {
      return nil
    }

    // Validate character positions are within line bounds
    if startPosition.line >= 0, startPosition.line < lines.count {
      let startLine = lines[startPosition.line]
      guard startPosition.character <= startLine.count else {
        return nil
      }
    }

    if endPosition.line >= 0, endPosition.line < lines.count {
      let endLine = lines[endPosition.line]
      guard endPosition.character <= endLine.count else {
        return nil
      }
    }

    // Calculate character offset for start and end positions
    let startOffset = characterOffset(for: startPosition, in: lines)
    let endOffset = characterOffset(for: endPosition, in: lines)

    guard startOffset <= content.count, endOffset <= content.count, startOffset <= endOffset else {
      return nil
    }

    // Apply the completion to get new content
    let beforeCompletion = String(content.prefix(startOffset))
    let afterCompletion = String(content.suffix(from: content.index(content.startIndex, offsetBy: endOffset)))
    let newContent = beforeCompletion + completion + afterCompletion

    // Calculate new cursor position (at the end of the inserted completion)
    let newCursorOffset = startOffset + completion.count
    let newCursorPosition = position(for: newCursorOffset, in: newContent)
    let newCursorSelection = Range(start: newCursorPosition, end: newCursorPosition)

    // Generate character-level diff
    guard let diffText = try? FileDiff.getCharacterDiff(oldContent: content, newContent: newContent) else {
      return nil
    }
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diffText,
      oldContent: content,
      newContent: newContent)
    // Convert to CompletionSuggestion format
    let diff = lineChanges.map { lineChanges in
      CodeCompletionServiceInterface.CompletionSuggestion.LineChange(
        changes: lineChanges.map { change in
          CodeCompletionServiceInterface.CompletionSuggestion.LineChange.WordChange(
            text: change.text,
            type: change.type)
        })
    }

    return CodeCompletionServiceInterface.CompletionSuggestion(
      file: file,
      newContent: newContent,
      newCursorSelection: newCursorSelection,
      diffLineStart: firstDiffLine,
      diff: diff)
  }

  private func characterOffset(for position: Position, in lines: [String]) -> Int {
    var offset = 0
    for (lineIndex, line) in lines.enumerated() {
      if lineIndex < position.line {
        offset += line.count + 1 // +1 for newline
      } else if lineIndex == position.line {
        offset += min(position.character, line.count)
        break
      }
    }
    return offset
  }

  private func position(for offset: Int, in content: String) -> Position {
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var currentOffset = 0

    for (lineIndex, line) in lines.enumerated() {
      let lineLength = line.count + 1 // +1 for newline
      if currentOffset + lineLength > offset {
        return Position(line: lineIndex, character: offset - currentOffset)
      }
      currentOffset += lineLength
    }

    // If we've gone past all lines, return the end of the last line
    let lastLineIndex = max(0, lines.count - 1)
    let lastLineLength = lines.last?.count ?? 0
    return Position(line: lastLineIndex, character: lastLineLength)
  }
}
