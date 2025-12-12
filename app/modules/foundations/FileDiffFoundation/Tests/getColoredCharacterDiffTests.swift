// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
@preconcurrency import SnapshotTesting
import SwiftUI
import Testing

// MARK: - GetColoredCharacterDiffTests

struct GetColoredCharacterDiffTests {

  @MainActor
  @Test("simple word change")
  func testSimpleWordChange() async throws {
    // Given: A simple function rename
    let oldContent = "func calculateSum(items: [Int]) -> Int {"
    let newContent = "func calculateTotal(items: [Int]) -> Int {"

    // Character changes: "Sum" -> "Total"
    let characterChanges: [[CharacterLevelChange]] = [
      [
        CharacterLevelChange(text: "func calculate", type: .unchanged),
        CharacterLevelChange(text: "Sum", type: .removed),
        CharacterLevelChange(text: "Total", type: .added),
        CharacterLevelChange(text: "(items: [Int]) -> Int {", type: .unchanged),
      ],
    ]

    // When
    let diff = try await FileDiff.getColoredCharacterDiff(
      oldContent: oldContent,
      newContent: newContent,
      characterChanges: characterChanges,
      diffLineStart: 0,
      language: .swift,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @MainActor
  @Test("multiline changes")
  func testMultilineChanges() async throws {
    // Given: A multiline code change
    let oldContent = """
      func test() {
        let x = 1
        print(x)
      }
      """
    let newContent = """
      func test() {
        let x = 42
        let y = x * 2
        print(y)
      }
      """

    // Character changes for lines 2-4
    let characterChanges: [[CharacterLevelChange]] = [
      // Line: "  let x = 1" -> "  let x = 42"
      [
        CharacterLevelChange(text: "  let x = ", type: .unchanged),
        CharacterLevelChange(text: "1", type: .removed),
        CharacterLevelChange(text: "42", type: .added),
        CharacterLevelChange(text: "\n", type: .unchanged),
      ],
      // Line: added "  let y = x * 2"
      [
        CharacterLevelChange(text: "  let y = x * 2\n", type: .added),
      ],
      // Line: "  print(x)" -> "  print(y)"
      [
        CharacterLevelChange(text: "  print(", type: .unchanged),
        CharacterLevelChange(text: "x", type: .removed),
        CharacterLevelChange(text: "y", type: .added),
        CharacterLevelChange(text: ")\n", type: .unchanged),
      ],
    ]

    // When
    let diff = try await FileDiff.getColoredCharacterDiff(
      oldContent: oldContent,
      newContent: newContent,
      characterChanges: characterChanges,
      diffLineStart: 1,
      language: .swift,
      highlightColors: .light(.xcode))

    // Then
    #expect(diff.lines.count == 3)
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @MainActor
  @Test("type change with syntax highlighting")
  func testTypeChangeWithSyntaxHighlighting() async throws {
    // Given: A type change that should show different highlighting for types
    let oldContent = "var items: [String] = []"
    let newContent = "var items: [Int] = []"

    let characterChanges: [[CharacterLevelChange]] = [
      [
        CharacterLevelChange(text: "var items: [", type: .unchanged),
        CharacterLevelChange(text: "String", type: .removed),
        CharacterLevelChange(text: "Int", type: .added),
        CharacterLevelChange(text: "] = []", type: .unchanged),
      ],
    ]

    // When
    let diff = try await FileDiff.getColoredCharacterDiff(
      oldContent: oldContent,
      newContent: newContent,
      characterChanges: characterChanges,
      diffLineStart: 0,
      language: .swift,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @MainActor
  @Test("string literal change")
  func testStringLiteralChange() async throws {
    // Given: A string literal change
    let oldContent = "print(\"Hello\")"
    let newContent = "print(\"World\")"

    let characterChanges: [[CharacterLevelChange]] = [
      [
        CharacterLevelChange(text: "print(\"", type: .unchanged),
        CharacterLevelChange(text: "Hello", type: .removed),
        CharacterLevelChange(text: "World", type: .added),
        CharacterLevelChange(text: "\")", type: .unchanged),
      ],
    ]

    // When
    let diff = try await FileDiff.getColoredCharacterDiff(
      oldContent: oldContent,
      newContent: newContent,
      characterChanges: characterChanges,
      diffLineStart: 0,
      language: .swift,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @MainActor
  @Test("dark mode colors")
  func testDarkModeColors() async throws {
    // Given: Simple code change with dark mode colors
    let oldContent = "let value = 10"
    let newContent = "let value = 20"

    let characterChanges: [[CharacterLevelChange]] = [
      [
        CharacterLevelChange(text: "let value = ", type: .unchanged),
        CharacterLevelChange(text: "10", type: .removed),
        CharacterLevelChange(text: "20", type: .added),
      ],
    ]

    // When
    let diff = try await FileDiff.getColoredCharacterDiff(
      oldContent: oldContent,
      newContent: newContent,
      characterChanges: characterChanges,
      diffLineStart: 0,
      language: .swift,
      highlightColors: .dark(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @MainActor
  @Test("complex code completion scenario")
  func testComplexCodeCompletionScenario() async throws {
    // Given: A realistic code completion scenario
    let oldContent = """
      struct User {
        let name: String
        let age: Int
      }
      """
    let newContent = """
      struct User {
        let name: String
        let email: String
        let age: Int
      }
      """

    // Character changes: adding a new property between name and age
    let characterChanges: [[CharacterLevelChange]] = [
      // Unchanged line ending and new line start
      [
        CharacterLevelChange(text: "  let name: String\n", type: .unchanged),
      ],
      // Added line
      [
        CharacterLevelChange(text: "  let email: String\n", type: .added),
      ],
      // Unchanged line
      [
        CharacterLevelChange(text: "  let age: Int\n", type: .unchanged),
      ],
    ]

    // When
    let diff = try await FileDiff.getColoredCharacterDiff(
      oldContent: oldContent,
      newContent: newContent,
      characterChanges: characterChanges,
      diffLineStart: 1,
      language: .swift,
      highlightColors: .light(.xcode))

    // Then
    #expect(diff.lines.count == 3)
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @MainActor
  @Test("keyword change preserves syntax colors")
  func testKeywordChangePreservesSyntaxColors() async throws {
    // Given: Change from var to let
    let oldContent = "var count = 0"
    let newContent = "let count = 0"

    let characterChanges: [[CharacterLevelChange]] = [
      [
        CharacterLevelChange(text: "var", type: .removed),
        CharacterLevelChange(text: "let", type: .added),
        CharacterLevelChange(text: " count = 0", type: .unchanged),
      ],
    ]

    // When
    let diff = try await FileDiff.getColoredCharacterDiff(
      oldContent: oldContent,
      newContent: newContent,
      characterChanges: characterChanges,
      diffLineStart: 0,
      language: .swift,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }
}

// MARK: - Test Helpers

extension FormattedCharacterDiff {
  func toHTML() throws -> String {
    var formattedDiff = AttributedString()
    let addedBackground = NSColor.green.withAlphaComponent(0.2)
    let removedBackground = NSColor.red.withAlphaComponent(0.2)

    for (lineIndex, line) in lines.enumerated() {
      // Apply diff styling to each change in the line
      var styledLine = line.content

      for change in line.changes {
        switch change.type {
        case .added:
          styledLine[change.range].backgroundColor = addedBackground
        case .removed:
          styledLine[change.range].backgroundColor = removedBackground
        case .unchanged:
          break
        }
      }

      formattedDiff.append(styledLine)

      // Add newline between lines (except for the last line)
      if lineIndex < lines.count - 1 {
        formattedDiff.append(AttributedString("\n"))
      }
    }

    return try formattedDiff.toHTML()
  }
}
