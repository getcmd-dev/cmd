// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FileDiffFoundation

// MARK: - ApplyLLMSuggestionTests

struct ApplyLLMSuggestionTests {

  @Test("no changes")
  func test_applyDiffWithNoChanges() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = ""
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == fileContent)
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent == """
      // 11
      // 2
      """.trimmingCharacters(in: .newlines))
  }

  @Test("search pattern not found")
  func test_applyDiffWithSearchPatternNotFound() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      Pattern that doesn't exist
      =======
      Replacement text
      >>>>>>> REPLACE
      """
    #expect(performing: { _ = try FileDiff.apply(searchReplacePattern: diff, to: fileContent) }, throws: { error in
      (error as? DiffError)?.errorDescription == "Could not find search pattern in original content"
    })
  }

  @Test("malformed diff")
  func test_applyDiffWithMalformedDiff() throws {
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
      Some unparsed content
      """
    #expect(performing: { _ = try FileDiff.apply(searchReplacePattern: diff, to: fileContent) }, throws: { error in
      (error as? DiffError)?.errorDescription == "The diff is not correctly formatted"
    })
  }

  @Test("other malformed diff")
  func test_applyDiffWithOtherMalformedDiff() throws {
    let fileContent = """
      Hello, world!
      What a wonderful world!
      So lucky to be here!
      """
    let diff = """
      <<<<<<< SEARCH
      Hello, world!
      =======
      Hello, universe!>>>>>>> REPLACE
      """
    #expect(performing: { _ = try FileDiff.apply(searchReplacePattern: diff, to: fileContent) }, throws: { error in
      (error as? DiffError)?.errorDescription == "The diff is not correctly formatted"
    })
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
    let newContent = try FileDiff.apply(searchReplacePattern: diff, to: fileContent)
    #expect(newContent.contains("A view that displays text with highlighted diffs (changed content)."))
  }
}

extension FileDiff {
  static func apply(searchReplacePattern: String, to content: String) throws -> String {
    let changes = try FileDiff.parse(searchReplacePattern: searchReplacePattern, for: content)
    return try FileDiff.apply(changes: changes, to: content)
  }
}
