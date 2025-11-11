// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffTypesFoundation
import Foundation
import Testing
@testable import FileDiffFoundation

// MARK: - SourceModificationHelpersTests

struct SourceModificationHelpersTests {

  struct SplitLinesTests {
    @Test("empty string")
    func test_emptyString() {
      let lines = "".splitLines()
      #expect(lines.isEmpty)
    }

    @Test("single line")
    func test_singleLine() {
      let lines = "Hello, world!".splitLines()
      #expect(lines == ["Hello, world!"])
    }

    @Test("multiple lines")
    func test_multipleLines() {
      let lines = "Hello, world!\nWhat a wonderful world!\nSo lucky to be here!\n".splitLines()
      #expect(lines == ["Hello, world!\n", "What a wonderful world!\n", "So lucky to be here!\n", ""])
    }

    @Test("multiple lines with no trailing newline")
    func test_multipleLinesWithNoTrailingNewline() {
      let lines = "Hello, world!\nWhat a wonderful world!\nSo lucky to be here!".splitLines()
      #expect(lines == ["Hello, world!\n", "What a wonderful world!\n", "So lucky to be here!"])
    }

    @Test("multiple lines empty lines")
    func test_multipleLinesWithEmptyline() {
      let lines = "Hello, world!\n\nWhat a wonderful world!\nSo lucky to be here!\n\n\n".splitLines()
      #expect(lines == ["Hello, world!\n", "\n", "What a wonderful world!\n", "So lucky to be here!\n", "\n", "\n", ""])
    }
  }

  // MARK: - Partial Edit Tests

  struct PartialEditTests {
    @Test("partial edit - add single line")
    func test_partialEdit_addSingleLine() throws {
      let fileContent = """
        Line 1
        Line 2
        Line 3
        Line 4
        """

      // Create a partial edit that only specifies adding a line after line 2
      let lineChanges: [LineChange] = [
        .unchanged(1, 1, 0..<0, "Line 2\n"),
        .added(2, 0..<0, "New Line\n"),
      ]

      let buffer = MockXCSourceTextBufferI(text: fileContent)
      try SourceModificationHelpers.update(buffer: buffer, with: FileChange(
        filePath: URL(filePath: ""),
        oldContent: "", // Partial edit doesn't have full old content
        suggestedNewContent: "",
        selectedChange: lineChanges))

      #expect(buffer.completeBuffer.contains("New Line"))
    }

    @Test("partial edit - remove single line")
    func test_partialEdit_removeSingleLine() throws {
      let fileContent = """
        Line 1
        Line 2
        Line 3
        Line 4
        """

      // Create a partial edit that only specifies removing line 2
      let lineChanges: [LineChange] = [
        .removed(1, 0..<0, "Line 2\n"),
      ]

      let buffer = MockXCSourceTextBufferI(text: fileContent)
      try SourceModificationHelpers.update(buffer: buffer, with: FileChange(
        filePath: URL(filePath: ""),
        oldContent: "", // Partial edit doesn't have full old content
        suggestedNewContent: "",
        selectedChange: lineChanges))

      #expect(!buffer.completeBuffer.contains("Line 2"))
      #expect(buffer.completeBuffer.contains("Line 1"))
      #expect(buffer.completeBuffer.contains("Line 3"))
    }

    @Test("partial edit - multiple changes")
    func test_partialEdit_multipleChanges() throws {
      let fileContent = """
        Line 1
        Line 2
        Line 3
        Line 4
        Line 5
        """

      // Remove line 2, add a new line after line 3
      let lineChanges: [LineChange] = [
        .removed(1, 0..<0, "Line 2\n"),
        .unchanged(2, 2, 0..<0, "Line 3\n"),
        .added(3, 0..<0, "Inserted Line\n"),
      ]

      let buffer = MockXCSourceTextBufferI(text: fileContent)
      try SourceModificationHelpers.update(buffer: buffer, with: FileChange(
        filePath: URL(filePath: ""),
        oldContent: "",
        suggestedNewContent: "",
        selectedChange: lineChanges))

      #expect(!buffer.completeBuffer.contains("Line 2"))
      #expect(buffer.completeBuffer.contains("Inserted Line"))
    }

    @Test("partial edit - validation fails on mismatched content")
    func test_partialEdit_validationFailsOnMismatchedContent() throws {
      let fileContent = """
        Line 1
        Line 2
        Line 3
        """

      // Try to remove a line with wrong content
      let lineChanges: [LineChange] = [
        .removed(1, 0..<0, "Wrong Content\n"),
      ]

      let buffer = MockXCSourceTextBufferI(text: fileContent)
      #expect(throws: Error.self) {
        try SourceModificationHelpers.update(buffer: buffer, with: FileChange(
          filePath: URL(filePath: ""),
          oldContent: "",
          suggestedNewContent: "",
          selectedChange: lineChanges))
      }
    }

    @Test("partial edit - validation fails on out of bounds line number")
    func test_partialEdit_validationFailsOnOutOfBoundsLineNumber() throws {
      let fileContent = """
        Line 1
        Line 2
        """

      // Try to remove a line that doesn't exist
      let lineChanges: [LineChange] = [
        .removed(10, 0..<0, "Line 11\n"),
      ]

      let buffer = MockXCSourceTextBufferI(text: fileContent)
      #expect(throws: Error.self) {
        try SourceModificationHelpers.update(buffer: buffer, with: FileChange(
          filePath: URL(filePath: ""),
          oldContent: "",
          suggestedNewContent: "",
          selectedChange: lineChanges))
      }
    }

    @Test("partial edit - with whitespace differences")
    func test_partialEdit_withWhitespaceDifferences() throws {
      let fileContent = """
        Line 1
          Line 2
        Line 3
        """

      // Remove line with extra whitespace (should trim and match)
      let lineChanges: [LineChange] = [
        .removed(1, 0..<0, "Line 2\n"), // No leading spaces in lineChange
      ]

      let buffer = MockXCSourceTextBufferI(text: fileContent)
      try SourceModificationHelpers.update(buffer: buffer, with: FileChange(
        filePath: URL(filePath: ""),
        oldContent: "",
        suggestedNewContent: "",
        selectedChange: lineChanges))

      #expect(!buffer.completeBuffer.contains("Line 2"))
    }

    @Test("full edit detection - matches buffer exactly")
    func test_fullEditDetection_matchesBufferExactly() throws {
      let fileContent = """
        Line 1
        Line 2
        Line 3
        """

      let lineChanges: [LineChange] = [
        .unchanged(0, 0, 0..<0, "Line 1\n"),
        .removed(1, 0..<0, "Line 2\n"),
        .added(1, 0..<0, "Modified Line\n"),
        .unchanged(2, 2, 0..<0, "Line 3"),
      ]

      let buffer = MockXCSourceTextBufferI(text: fileContent)
      try SourceModificationHelpers.update(buffer: buffer, with: FileChange(
        filePath: URL(filePath: ""),
        oldContent: fileContent, // Full old content matches
        suggestedNewContent: "",
        selectedChange: lineChanges))

      #expect(buffer.completeBuffer.contains("Modified Line"))
      #expect(!buffer.completeBuffer.contains("Line 2\n"))
    }
  }

  @Test("no changes")
  func test_applyDiffWithNoChanges() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = ""
    #expect(try apply(diff, to: fileContent) == fileContent)
  }

  @Test("simple search and replace")
  func test_applyDiffWithSimpleSearchAndReplace() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      Hello, world!
      =======
      Hello, universe!
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      Hello, universe!
      What a wonderful world!
      So lucky to be here!
      """)
  }

  @Test("replace multiple lines")
  func test_applyDiffWithMultipleLines() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      What a wonderful world!
      So lucky to be here!
      =======
      What a wonderful universe!
      So grateful to be here!
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      Hello, world!
      What a wonderful universe!
      So grateful to be here!
      """)
  }

  @Test("add new line")
  func test_applyDiffWithNewLine() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      What a wonderful world!
      =======
      What a wonderful world!
      What a time to be alive!
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      Hello, world!
      What a wonderful world!
      What a time to be alive!
      So lucky to be here!
      """)
  }

  @Test("add new line at the beginning")
  func test_applyDiffWithNewLineAtBeginning() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      Hello, world!
      =======
      What a time to be alive!
      Hello, world!
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      What a time to be alive!
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """)
  }

  @Test("add new line at the end")
  func test_applyDiffWithNewLineAtEnd() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      So lucky to be here!
      =======
      So lucky to be here!
      What a time to be alive!
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      What a time to be alive!
      """)
  }

  @Test("delete line at beginning of file")
  func test_applyDiffWithDeletedLineAtBeginningOfFile() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      Hello, world!
      =======
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      What a wonderful world!
      So lucky to be here!
      """)
  }

  @Test("delete line in middle of file")
  func test_applyDiffWithDeletedLineInMiddleOfFile() throws {
    let fileContent = """
      // 1
      // 2
      // 3
      // 4

      """
    let diff = """
      <<<<<<< SEARCH
      // 2
      =======
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      // 1
      // 3
      // 4

      """)
  }

  @Test("delete line at the end of file")
  func test_applyDiffWithDeletedLineAtTheEndOfFile() throws {
    let fileContent = """
      // 1
      // 2
      // 3
      // 4

      """
    let diff = """
      <<<<<<< SEARCH
      // 4
      =======
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      // 1
      // 2
      // 3

      """)
  }

  @Test("delete line at the end of file with no trailing newline")
  func test_applyDiffWithDeletedLineAtTheEndOfFileWithNoTrailingNewLine() throws {
    let fileContent = """
      // 1
      // 2
      // 3
      // 4
      """
    let diff = """
      <<<<<<< SEARCH
      // 4
      =======
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      // 1
      // 2
      // 3
      """)
  }

  @Test("replaces the entire file")
  func test_replaceTheEntireFile() throws {
    let fileContent = """
      // 1

      """
    let diff = """
      <<<<<<< SEARCH
      // 1
      =======
      // 2
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      // 2

      """)
  }

  @Test("replaces the entire file with no trailing newline")
  func test_replaceTheEntireFileWithNoTrailingNewLine() throws {
    let fileContent = """
      // 1
      """
    let diff = """
      <<<<<<< SEARCH
      // 1
      =======
      // 2
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      // 2
      """)
  }

  @Test("adds to an empty file")
  func test_addToEmptyfile() throws {
    let fileContent = ""
    let diff = """
      <<<<<<< SEARCH
      =======
      // 2
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      // 2

      """)
  }

  @Test("modify line")
  func test_applyDiffWithModifiedLine() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      Hello, world!
      =======
      Hello, wooorld!
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      Hello, wooorld!
      What a wonderful world!
      So lucky to be here!
      """)
  }

  @Test("new, modified and deleted line")
  func test_applyDiffWithNewModifiedAndDeletedLine() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      Hello, world!
      What a wonderful world!
      =======
      Hello, wooorld!
      What a time to be alive!
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      Hello, wooorld!
      What a time to be alive!
      So lucky to be here!
      """)
  }

  @Test("multiple search and replace blocks")
  func test_applyDiffWithMultipleSearchAndReplaceBlocks() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      Hello, world!
      =======
      Hello, universe!
      >>>>>>> REPLACE
      <<<<<<< SEARCH
      So lucky to be here!
      =======
      So grateful to be here!
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      Hello, universe!
      What a wonderful world!
      So grateful to be here!
      """)
  }

  @Test("replaces the entire file with no trailing newline")
  func test_doesntMatchPatternWithinALine() throws {
    let fileContent = """
      // 11
      // 1
      """.trimmingCharacters(in: .newlines)
    let diff = """
      <<<<<<< SEARCH
      // 1
      =======
      // 2
      >>>>>>> REPLACE
      """
    #expect(try apply(diff, to: fileContent) == """
      // 11
      // 2
      """.trimmingCharacters(in: .newlines))
  }

  @Test("real example")
  func test_realExample() throws {
    let fileContent = """

      import DLS
      import SwiftUI

      public struct DiffView: View {

        // MARK: Public

        public var body: some View {
          content
            .readSize(Binding(
              get: { CGSize(width: desiredWidth ?? 0, height: desiredHeight ?? 0) },
              set: { newValue in
                desiredWidth = newValue.width
                desiredHeight = newValue.height
              }))
          HStack {
            content
              .background(.background)
            Spacer()
          }
          .frame(maxWidth: maxWidth, minHeight: height, maxHeight: height)
          .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
          } action: { newValue in
            maxWidth = newValue.width
          }
        }

        // MARK: Internal

        let diffContent: AttributedString
        let changedRanges: [Range<AttributedString.Index>]

        var height: CGFloat {
          (desiredHeight ?? 0) + 400
        }

        // MARK: Private

        @State private var desiredWidth: CGFloat?
        @State private var desiredHeight: CGFloat?
        @State private var maxWidth = CGFloat.infinity

        @ViewBuilder
        private var content: some View {
          Text(diffContent)
            .font(Font.custom("Menlo", fixedSize: 11))
            .fixedSize()
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(5)
            .textSelection(.enabled)
        }

      }

      """

    let diff = """
      <<<<<<< SEARCH
      public struct DiffView: View {

        // MARK: Public
      =======
      /// A view that displays text with highlighted diffs (changed content).
      ///
      /// `DiffView` renders text content with special highlighting for sections that have changed.
      /// It automatically sizes itself based on the content while respecting layout constraints.
      public struct DiffView: View {

        // MARK: Public
      >>>>>>> REPLACE
      <<<<<<< SEARCH
        // MARK: Internal

        let diffContent: AttributedString
        let changedRanges: [Range<AttributedString.Index>]
      =======
        // MARK: Internal

        /// The text content to display with diff highlights.
        let diffContent: AttributedString

        /// Ranges within the attributed string that should be highlighted as changed.
        let changedRanges: [Range<AttributedString.Index>]
      >>>>>>> REPLACE
      <<<<<<< SEARCH
        var height: CGFloat {
          (desiredHeight ?? 0) + 400
        }
      =======
        /// Calculated height for the diff view.
        ///
        /// Adds padding to the content's desired height to ensure proper display.
        var height: CGFloat {
          (desiredHeight ?? 0) + 400
        }
      >>>>>>> REPLACE
      <<<<<<< SEARCH
        // MARK: Private

        @State private var desiredWidth: CGFloat?
        @State private var desiredHeight: CGFloat?
        @State private var maxWidth = CGFloat.infinity
      =======
        // MARK: Private

        /// The calculated width of the content.
        @State private var desiredWidth: CGFloat?

        /// The calculated height of the content.
        @State private var desiredHeight: CGFloat?

        /// The maximum width constraint for the view.
        @State private var maxWidth = CGFloat.infinity
      >>>>>>> REPLACE
      <<<<<<< SEARCH
        @ViewBuilder
        private var content: some View {
      =======
        /// The styled text content with appropriate formatting for diff display.
        @ViewBuilder
        private var content: some View {
      >>>>>>> REPLACE

      """
    let newContent = try apply(diff, to: fileContent)
    #expect(newContent.contains("A view that displays text with highlighted diffs (changed content)."))
  }

  private func apply(_ diff: String, to fileContent: String) throws -> String {
    let changes = try FileDiff.getFileChange(applying: diff, to: fileContent)
    let buffer = MockXCSourceTextBufferI(text: fileContent)
    try SourceModificationHelpers.update(buffer: buffer, with: FileChange(
      filePath: URL(filePath: ""),
      oldContent: changes.oldContent,
      suggestedNewContent: changes.newContent,
      selectedChange: changes.diff))
    return buffer.completeBuffer
  }

}

extension LineChange {
  static func unchanged(_ oldLine: Int, _ newLine: Int, _ characterRange: Range<Int>, _ content: String) -> LineChange {
    .unchanged(oldLine: oldLine, newLine: newLine, characterRange: characterRange, content: content)
  }

  static func added(_ newLine: Int, _ characterRange: Range<Int>, _ content: String) -> LineChange {
    .added(newLine: newLine, characterRange: characterRange, content: content)
  }

  static func removed(_ oldLine: Int, _ characterRange: Range<Int>, _ content: String) -> LineChange {
    .removed(oldLine: oldLine, characterRange: characterRange, content: content)
  }
}
