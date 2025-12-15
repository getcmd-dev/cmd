// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import FileDiffTypesFoundation

// MARK: - NextWorkSuggestion

struct NextWorkSuggestion {
  let newCompletion: CompletionSuggestion
  let remainingCompletion: CompletionSuggestion?
}

extension CompletionSuggestion {
  /// Return the completion that corresponds to accepting the suggested word at the current cursor position.
  func completionWithNextWord(from cursorPosition: Position) -> NextWorkSuggestion? {
    guard
      cursorPosition.line >= diffLineStart,
      cursorPosition.line < diffLineStart + self.diff.count,
      cursorPosition.character <= self.diff[cursorPosition.line - diffLineStart].changes.filter({ $0.type != .added }).reduce(
        0,
        { $0 + $1.text.count })
    else {
      return nil
    }
    var diff = [LineChange]()
    var remainingdiff = [LineChange]()
    for i in 0..<cursorPosition.line - diffLineStart {
      diff
        .append(.init(changes: self.diff[i].changes.filter { $0.type != .added }.map { .init(text: $0.text, type: .unchanged) }))
      remainingdiff.append(self.diff[i])
    }
    // split line by words
    let lineDiff = self.diff[cursorPosition.line - diffLineStart].changes.flatMap { change in
      change.text.splitWords().map { CharacterLevelChange(text: String($0), type: change.type) }
    }
    var c = cursorPosition.character
    var i = 0
    var newCursorPosition = cursorPosition
    while c >= 0, i < lineDiff.count {
      if c >= lineDiff[i].text.count {
        c -= lineDiff[i].text.count
        i += 1
      } else {
        if lineDiff[i].type == .unchanged {
          // Skip to the next change.
          let movedCursorPosition: Position =
            if lineDiff[i].text.hasSuffix("\n") {
              .init(line: cursorPosition.line + 1, character: 0)
            } else {
              .init(line: cursorPosition.line, character: cursorPosition.character + lineDiff[i].text.count - c)
            }
          return completionWithNextWord(from: movedCursorPosition)
        }

        let isNextChangeNewLine = i == lineDiff.count - 2 && lineDiff.last?.text == "\n"
        let includedChanges = isNextChangeNewLine ? [i, i + 1] : [i] // When the next change is a new line, include it.
        diff.append(.init(changes: lineDiff
            .enumerated()
            .filter { $0.element.type != .added || includedChanges.contains($0.offset) }
            .map { CharacterLevelChange(
              text: $0.element.text,
              type: includedChanges.contains($0.offset) ? $0.element.type : .unchanged) }
            .merged))
        remainingdiff.append(.init(changes: lineDiff
            .enumerated()
            .map { CharacterLevelChange(
              text: $0.element.text,
              type: includedChanges.contains($0.offset) ? .unchanged : $0.element.type) }
            .merged))
        let newLines = lineDiff[i].text.split(separator: "\n", omittingEmptySubsequences: false)
        if newLines.count > 1 {
          newCursorPosition.line += newLines.count - 1
          newCursorPosition.character = newLines.last?.count ?? 0
        } else {
          newCursorPosition.character += lineDiff[i].text.count - c
        }
        break
      }
    }
    if c < 0 || i == lineDiff.count {
      // could not find match
      return nil
    }
    for i in cursorPosition.line - diffLineStart + 1..<self.diff.count {
      diff
        .append(.init(changes: self.diff[i].changes.filter { $0.type != .added }.map { .init(text: $0.text, type: .unchanged) }))
      remainingdiff.append(self.diff[i])
    }

    // Compute new content
    let lines = oldContent.splitLines()
    let prefix = lines.prefix(diffLineStart)

    let oldContentInDiff = self.diff
      .map({ $0.changes.filter { $0.type != .added } })
      .filter { !$0.isEmpty }

    var oldLinesInDiff = oldContentInDiff
      .flatMap(\.self)
      .reduce(into: 0) { acc, el in acc += el.text.split(separator: "\n", omittingEmptySubsequences: false).count - 1 }
    if oldContentInDiff.last?.last?.text.hasSuffix("\n") != true {
      // No trailing new line.
      oldLinesInDiff += 1
    }

    let suffix = lines.suffix(max(0, lines.count - diffLineStart - oldLinesInDiff))
    let newContent = prefix.joined() + diff.flatMap(\.changes).map { $0.type == .removed ? "" : $0.text }.joined() + suffix
      .joined()

    let newCompletion = CompletionSuggestion(
      file: file,
      oldContent: oldContent,
      newContent: newContent,
      newCursorSelection: .init(start: newCursorPosition, end: newCursorPosition),
      diffLineStart: diffLineStart,
      diff: diff)
    let remainingCompletion = CompletionSuggestion(
      file: file,
      oldContent: newContent,
      newContent: self.newContent,
      newCursorSelection: newCursorSelection,
      diffLineStart: diffLineStart,
      diff: remainingdiff)
    return NextWorkSuggestion(newCompletion: newCompletion, remainingCompletion: remainingCompletion)
  }
}

extension String {
  /// Split the string in chunks that end by a continous block of non-whitespace character, preceded by whitespaces
  /// Examples:
  /// "some sentence" -> ["some", " sentence"]
  /// "private   func foo()" -> ["private", "   func", " foo()"]
  func splitWords() -> [String.SubSequence] {
    // Match: (optional whitespace followed by non-whitespace) OR (trailing whitespace only)
    let matches = matches(of: /\s*\S+|\s+/)
    return matches.map(\.output)
  }
}
