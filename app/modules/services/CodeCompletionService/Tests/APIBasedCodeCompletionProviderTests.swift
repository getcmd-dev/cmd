// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
import Foundation
import Testing
@testable import CodeCompletionService

// MARK: - Offset Calculation Tests
//
// These tests verify the splitContent() function used by APIBasedCodeCompletionProvider

@Suite("Offset Calculation for API-Based Code Completion")
struct OffsetCalculationTests {

  @Test("Offset calculation for single line file")
  func offsetCalculationSingleLine() throws {
    let content = "let x = 1"
    let position = Position(line: 0, character: 5)

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    #expect(prefix == "let x")
    #expect(suffix == " = 1")
    #expect(prefix + suffix == content)
  }

  @Test("Offset calculation throws on invalid selection line")
  func offsetCalculationInvalidLine() throws {
    let content = "let x = 1\nlet y = 2"
    let position = Position(line: 10, character: 0)

    #expect(throws: AppError.self) {
      try APIBasedCodeCompletionProvider.splitContent(content, at: position)
    }
  }

  @Test("Offset calculation throws on invalid character offset")
  func offsetCalculationInvalidCharacter() throws {
    let content = "let x = 1"
    let position = Position(line: 0, character: 100)

    #expect(throws: AppError.self) {
      try APIBasedCodeCompletionProvider.splitContent(content, at: position)
    }
  }

  @Test("Offset calculation handles multi-byte characters (emoji)")
  func offsetCalculationMultiByte() throws {
    let content = "let emoji = 😀"
    let position = Position(line: 0, character: 13)

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    #expect(prefix == "let emoji = 😀")
    #expect(suffix == "")
  }

  @Test("Offset calculation handles Japanese characters")
  func offsetCalculationJapanese() throws {
    let content = "let text = \"日本語\""
    let position = Position(line: 0, character: 12) // After "let text = \""

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    #expect(prefix == "let text = \"")
    #expect(suffix == "日本語\"")
  }

  @Test("Offset calculation at start of file")
  func offsetCalculationStartOfFile() throws {
    let content = "func test() {}"
    let position = Position(line: 0, character: 0)

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    #expect(prefix == "")
    #expect(suffix == "func test() {}")
    // offset calculation verified via prefix + suffix == content 0)
  }

  @Test("Offset calculation at end of file")
  func offsetCalculationEndOfFile() throws {
    let content = "func test() {}"
    let position = Position(line: 0, character: 14)

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    #expect(prefix == "func test() {}")
    #expect(suffix == "")
    // offset calculation verified via prefix + suffix == content 14)
  }

  @Test("Offset calculation with empty file")
  func offsetCalculationEmptyFile() throws {
    let content = ""
    let position = Position(line: 0, character: 0)

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    #expect(prefix == "")
    #expect(suffix == "")
    // offset calculation verified via prefix + suffix == content 0)
  }

  @Test("Offset calculation for multi-line file")
  func offsetCalculationMultiLine() throws {
    let content = """
      func test() {
        let x = 1
        let y = 2
      }
      """
    let position = Position(line: 2, character: 2)

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    #expect(prefix == "func test() {\n  let x = 1\n  ")
    #expect(suffix == "let y = 2\n}\n")
  }

  @Test("Offset calculation with CRLF line endings")
  func offsetCalculationCRLF() throws {
    let content = "line1\r\nline2\r\nline3"
    let position = Position(line: 1, character: 3)

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    // Should handle CRLF as part of the line
    #expect(prefix == "line1\r\nlin")
    #expect(suffix == "e2\r\nline3")
  }

  @Test("Prefix plus suffix equals original content")
  func prefixPlusSuffixEqualsContent() throws {
    let content = """
      func example() {
        let value = "test"
        return value
      }
      """
    let position = Position(line: 1, character: 10)

    let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)

    #expect(prefix + suffix == content)
  }

  @Test("Multiple positions in same file")
  func multiplePositionsInSameFile() throws {
    let content = "abc\ndef\nghi"

    let positions = [
      Position(line: 0, character: 0), // Start
      Position(line: 0, character: 3), // End of first line
      Position(line: 1, character: 0), // Start of second line
      Position(line: 1, character: 3), // End of second line
      Position(line: 2, character: 3), // End of file
    ]

    for position in positions {
      let (prefix, suffix) = try APIBasedCodeCompletionProvider.splitContent(content, at: position)
      #expect(prefix + suffix == content)
    }
  }
}
