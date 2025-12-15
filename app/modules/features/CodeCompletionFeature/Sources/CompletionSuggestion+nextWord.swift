// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import FileDiffTypesFoundation

extension CompletionSuggestion {
  /// Return the completion that corresponds to accepting the suggested word at the current cursor position.
  func completionWithNextWord(from cursorPosition: Position) -> CompletionSuggestion? {
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
    for i in 0..<cursorPosition.line - diffLineStart {
      diff
        .append(.init(changes: self.diff[i].changes.filter { $0.type != .added }.map { .init(text: $0.text, type: .unchanged) }))
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
        diff.append(.init(changes: lineDiff
            .enumerated()
            .filter { $0.element.type != .added || $0.offset == i }
            .map { CharacterLevelChange(text: $0.element.text, type: $0.offset == i ? $0.element.type : .unchanged) }))
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
    }

    // Compute new content
    let lines = oldContent.splitLines()
    let prefix = lines.prefix(diffLineStart)
    let oldLinesInDiff = self.diff
      .flatMap(\.changes)
      .filter { $0.type != .added }
      .reduce(into: 0) { acc, el in acc += el.text.split(separator: "\n", omittingEmptySubsequences: false).count - 1 }
    let suffix = lines.suffix(lines.count - diffLineStart - oldLinesInDiff - 1)
    let newContent = prefix.joined() + diff.flatMap(\.changes).map { $0.type == .removed ? "" : $0.text }.joined() + suffix
      .joined()

    return CompletionSuggestion(
      file: file,
      oldContent: oldContent,
      newContent: newContent,
      newCursorSelection: .init(start: newCursorPosition, end: newCursorPosition),
      diffLineStart: diffLineStart,
      diff: diff)
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
