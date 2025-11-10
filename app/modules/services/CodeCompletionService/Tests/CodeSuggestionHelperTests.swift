// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Foundation
import Testing
@testable import CodeCompletionService

struct CodeSuggestionHelperTests {
  @Test("Apply simple completion")
  func applySimpleCompletion() throws {
    // given
    let oldContent = "Hello World"
    let file = URL(fileURLWithPath: "/test.swift")
    let selection = Range(start: Position(line: 0, character: 6), end: Position(line: 0, character: 6))

    let suggestion = CodeCompletionFoundation.CompletionSuggestion(
      file: file,
      startPosition: Position(line: 0, character: 6),
      endPosition: Position(line: 0, character: 11),
      completion: "Swift",
      id: UUID())

    // when
    let result = try #require(suggestion.applied(to: oldContent, file: file, selection: selection))

    // then
    #expect(result.file == file)
    #expect(result.newContent == "Hello Swift")
    #expect(result.newCursorSelection.start.line == 0)
    #expect(result.newCursorSelection.start.character == 11)
    #expect(result.diffLineStart == 0)
    #expect(result.diff.debugDescription == "Hello {-World-}{+Swift+}")
  }

  @Test("Apply multiline completion")
  func applyMultilineCompletion() throws {
    // given
    let oldContent = """
      func hello() {
        print("Hello")
      }
      """
    let file = URL(fileURLWithPath: "/test.swift")
    let selection = Range(start: Position(line: 0, character: 10), end: Position(line: 0, character: 10))

    let suggestion = CodeCompletionFoundation.CompletionSuggestion(
      file: file,
      startPosition: Position(line: 0, character: 10),
      endPosition: Position(line: 0, character: 12),
      completion: "(name: String)",
      id: UUID())

    // when
    let result = try #require(suggestion.applied(to: oldContent, file: file, selection: selection))

    // then
    #expect(result.file == file)
    #expect(result.newContent.hasPrefix("func hello(name: String)"))
    #expect(result.newCursorSelection.start.line == 0)
    #expect(result.diffLineStart == 0)
    #expect(result.diff.debugDescription == "func hello({+name: String+}) {\n")
  }

  @Test("Apply completion with character-level diff")
  func applyCompletionWithCharacterDiff() throws {
    // given
    let oldContent = "var x = 5"
    let file = URL(fileURLWithPath: "/test.swift")
    let selection = Range(start: Position(line: 0, character: 8), end: Position(line: 0, character: 8))

    let suggestion = CodeCompletionFoundation.CompletionSuggestion(
      file: file,
      startPosition: Position(line: 0, character: 8),
      endPosition: Position(line: 0, character: 9),
      completion: "10",
      id: UUID())

    // when
    let result = try #require(suggestion.applied(to: oldContent, file: file, selection: selection))

    // then
    #expect(result.file == file)
    #expect(result.newContent == "var x = 10")
    #expect(result.diff.debugDescription == "var x = {-5-}{+10+}")

    // Verify diff contains character-level changes
    let firstLine = try #require(result.diff.first)
    let hasRemovedChars = firstLine.changes.contains { $0.type == .removed }
    let hasAddedChars = firstLine.changes.contains { $0.type == .added }
    #expect(hasRemovedChars)
    #expect(hasAddedChars)
  }

  @Test("Apply completion at end of file")
  func applyCompletionAtEndOfFile() throws {
    // given
    let oldContent = "func test()"
    let file = URL(fileURLWithPath: "/test.swift")
    let selection = Range(start: Position(line: 0, character: 11), end: Position(line: 0, character: 11))

    let suggestion = CodeCompletionFoundation.CompletionSuggestion(
      file: file,
      startPosition: Position(line: 0, character: 11),
      endPosition: Position(line: 0, character: 11),
      completion: " { }",
      id: UUID())

    // when
    let result = try #require(suggestion.applied(to: oldContent, file: file, selection: selection))

    // then
    #expect(result.file == file)
    #expect(result.newContent == "func test() { }")
    #expect(result.newCursorSelection.start.character == 15)
  }

  @Test("Apply completion with invalid positions returns nil")
  func applyCompletionWithInvalidPositions() throws {
    // given
    let oldContent = "Hello"
    let file = URL(fileURLWithPath: "/test.swift")
    let selection = Range(start: Position(line: 0, character: 0), end: Position(line: 0, character: 0))

    let suggestion = CodeCompletionFoundation.CompletionSuggestion(
      file: file,
      startPosition: Position(line: 0, character: 20),
      endPosition: Position(line: 0, character: 25),
      completion: "World",
      id: UUID())

    // when
    let result = suggestion.applied(to: oldContent, file: file, selection: selection)

    // then
    #expect(result == nil)
  }

  @Test("Cursor position calculation is correct")
  func cursorPositionCalculation() throws {
    // given
    let oldContent = """
      line 1
      line 2
      line 3
      """
    let file = URL(fileURLWithPath: "/test.swift")
    let selection = Range(start: Position(line: 1, character: 5), end: Position(line: 1, character: 5))

    let suggestion = CodeCompletionFoundation.CompletionSuggestion(
      file: file,
      startPosition: Position(line: 1, character: 5),
      endPosition: Position(line: 1, character: 6),
      completion: " updated",
      id: UUID())

    // when
    let result = try #require(suggestion.applied(to: oldContent, file: file, selection: selection))

    // then
    #expect(result.newCursorSelection.start.line == 1)
    #expect(result.newCursorSelection.start.character == 13)
  }

  @Test("Includes correct line range")
  func includesCorrectLineRange() throws {
    // given
    let oldContent = """
      line 1
      line 2
      line 3
      """
    let file = URL(fileURLWithPath: "/test.swift")
    let selection = Range(start: Position(line: 1, character: 1), end: Position(line: 1, character: 1))

    let suggestion = CodeCompletionFoundation.CompletionSuggestion(
      file: file,
      startPosition: Position(line: 1, character: 0),
      endPosition: Position(line: 1, character: 6),
      completion: "line 20",
      id: UUID())

    // when
    let result = try #require(suggestion.applied(to: oldContent, file: file, selection: selection))

    // then
    #expect(result.diff.debugDescription == "line 2{+0+}\n")
  }
}
