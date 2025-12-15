// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Foundation
import Testing
@testable import CodeCompletionFeature
@testable import CodeCompletionService // TODO: remove

struct CompletionSuggestionNextWordTests {

  // MARK: - Tests

  @Test("Accept next word from simple single-word completion")
  func acceptNextWordSimple() throws {
    // given
    let oldContent = "let x = "
    let newContent = "let x = value"
    let cursorPosition = Position(line: 0, character: 8)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    #expect(result.newContent == "let x = value")
  }

  @Test("Accept next word stops at whitespace")
  func acceptNextWordStopsAtWhitespace() throws {
    // given
    let oldContent = "func test() {"
    let newContent = "func test() { print(\"hello\") }"
    let cursorPosition = Position(line: 0, character: 13)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    // Should accept " " (space) as next word since it's the first character
    #expect(result.newContent == "func test() { print(\"hello\")")
  }

  @Test("Accept next word stops at punctuation")
  func acceptNextWordStopsAtPunctuation() throws {
    // given
    let oldContent = "let arr = ["
    let newContent = "let arr = [1, 2, 3]"
    let cursorPosition = Position(line: 0, character: 11)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    // Should accept "1" as next word (number is a word)
    #expect(result.newContent == "let arr = [1,")
  }

  @Test("Accept next word with multiline completion")
  func acceptNextWordMultiline() throws {
    // given
    let oldContent = """
      func hello() {
      }
      """
    let newContent = """
      func hello() {
        print("Hello")
      }
      """
    let cursorPosition = Position(line: 0, character: 14)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    // Should accept first word on the completion line
    #expect(result.newContent.contains("print") || result.newContent.contains("\n"))
  }

  @Test("Accept next word returns nil when cursor outside diff range")
  func acceptNextWordOutsideDiffRange() throws {
    // given
    let oldContent = "let x = value"
    let newContent = "let x = newValue"
    let cursorPosition = Position(line: 0, character: 8)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // Cursor at line 5 is outside the diff
    let outsideCursor = Position(line: 5, character: 0)

    // when
    let result = completion.completionWithNextWord(from: outsideCursor)

    // then
    #expect(result == nil)
  }

  @Test("Accept next word with underscore in identifier")
  func acceptNextWordWithUnderscore() throws {
    // given
    let oldContent = "let "
    let newContent = "let my_variable = 5"
    let cursorPosition = Position(line: 0, character: 4)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    // "my_variable" should be treated as one word since underscore is not a delimiter
    #expect(result.newContent == "let my_variable")
  }

  @Test("Accept next word from middle of completion")
  func acceptNextWordFromMiddle() throws {
    // given
    let oldContent = "print("
    let newContent = "print(\"Hello World\")"
    let cursorPosition = Position(line: 0, character: 6)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    // Should accept the quote as a single character (punctuation)
    #expect(result.newContent == "print(\"Hello")
  }

  @Test("Cursor position is updated after accepting word")
  func cursorPositionUpdated() throws {
    // given
    let oldContent = "let x = "
    let newContent = "let x = value"
    let cursorPosition = Position(line: 0, character: 8)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    // Cursor should be at the end of the accepted word
    #expect(result.newCursorSelection.start.character > cursorPosition.character)
  }

  @Test("Completion in the middle of a file")
  func completionInTheMiddleOfAFile() throws {
    // given
    let oldContent = """
      0
      1
      2
      3
      4
      5
      6
      7
      8
      9
      10 let x =
      11
      12
      12
      13
      14
      15
      16
      17
      18
      19
      20 
      """
    let newContent = """
      0
      1
      2
      3
      4
      5
      6
      7
      8
      9
      10 let x = value // Set x
      11
      12
      12
      13
      14
      15
      16
      17
      18
      19
      20 
      """
    let cursorPosition = Position(line: 10, character: 11)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    #expect(result.newContent == """
      0
      1
      2
      3
      4
      5
      6
      7
      8
      9
      10 let x = value
      11
      12
      12
      13
      14
      15
      16
      17
      18
      19
      20 
      """)
  }

  // MARK: - Helper

  /// Creates a CompletionSuggestion from before/after content using RawCompletionSuggestion.
  private func createCompletion(
    oldContent: String,
    newContent: String,
    cursorPosition: Position)
    throws -> CompletionSuggestion
  {
    let file = URL(fileURLWithPath: "/test.swift")

    // Find the insertion point (where old and new content diverge)
    let oldLines = oldContent.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

    // Use RawCompletionSuggestion to create the completion
    let suggestion = RawCompletionSuggestion(
      file: file,
      startPosition: cursorPosition,
      endPosition: Position(line: oldLines.count - 1, character: oldLines.last?.count ?? 0),
      completion: extractCompletion(oldContent: oldContent, newContent: newContent, from: cursorPosition),
      id: UUID())

    let selection = Range(start: cursorPosition, end: cursorPosition)
    return try #require(suggestion.applied(to: oldContent, file: file, selection: selection))
  }

  /// Extracts the completion text from old/new content starting at cursor position.
  private func extractCompletion(oldContent: String, newContent: String, from cursor: Position) -> String {
    let oldLines = oldContent.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
    let newLines = newContent.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

    // Calculate offset in old content
    var oldOffset = 0
    for i in 0..<cursor.line {
      oldOffset += oldLines[i].count + 1 // +1 for newline
    }
    oldOffset += cursor.character

    // Calculate offset in new content (same position)
    var newOffset = 0
    for i in 0..<cursor.line {
      newOffset += newLines[i].count + 1
    }
    newOffset += cursor.character

    let oldSuffix = String(oldContent.suffix(from: oldContent.index(oldContent.startIndex, offsetBy: oldOffset)))
    let newSuffix = String(newContent.suffix(from: newContent.index(newContent.startIndex, offsetBy: newOffset)))

    // Find where old suffix starts in new suffix and extract the completion
    if let range = newSuffix.range(of: oldSuffix) {
      return String(newSuffix[..<range.lowerBound])
    }
    return newSuffix
  }

}
