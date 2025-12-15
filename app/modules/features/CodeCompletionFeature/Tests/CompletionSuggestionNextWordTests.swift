// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Foundation
import Testing
@testable import CodeCompletionFeature

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
    #expect(result.newCompletion.newContent == "let x = value")
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
    #expect(result.newCompletion.newContent == "func test() { print(\"hello\")")
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
    #expect(result.newCompletion.newContent == "let arr = [1,")
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
    let result1 = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    // First completion moves to the next line
    #expect(result1.newCompletion.newContent == """
      func hello() {
      }
      """)
    #expect(result1.newCompletion.newCursorSelection.start.line == 1)

    // when
    let result2 = try #require(result1.remainingCompletion?
      .completionWithNextWord(from: result1.newCompletion.newCursorSelection.start))

    // then
    // Second completion moves to the new line
    #expect(result2.newCompletion.newContent == """
      func hello() {
        print("Hello")
      }
      """)
    #expect(result2.newCompletion.newCursorSelection.start.line == 1)
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
    #expect(result.newCompletion.newContent == "let my_variable")
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
    #expect(result.newCompletion.newContent == "print(\"Hello")
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
    #expect(result.newCompletion.newCursorSelection.start.character > cursorPosition.character)
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
    let cursorPosition = Position(line: 10, character: 10)

    let completion = try createCompletion(
      oldContent: oldContent,
      newContent: newContent,
      cursorPosition: cursorPosition)

    // when
    let result = try #require(completion.completionWithNextWord(from: cursorPosition))

    // then
    #expect(result.newCompletion.newContent == """
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
    cursorPosition _: Position)
    throws -> CompletionSuggestion
  {
    let file = URL(fileURLWithPath: "/test.swift")
    guard let completion = CompletionSuggestion(file: file, oldContent: oldContent, newContent: newContent) else {
      throw AppError("Could not create CompletionSuggestion")
    }
    return completion
  }

}
