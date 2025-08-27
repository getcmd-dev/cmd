// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Testing

import Foundation
@testable import DLS

struct RichTextEditorTests {

  @Test
  func test_adjustedTextBlockRangeOnSelectionChange() throws {
    let attrString = NSMutableAttributedString()
    attrString.append(NSAttributedString(string: "Hello "))
    attrString.append(NSAttributedString(string: "World", attributes: [
      .lockedAttributes: [
        NSAttributedString.Key.foregroundColor,
        NSAttributedString.Key.backgroundColor,
      ],
      .textBlock: UUID().uuidString,
    ]))
    attrString.append(NSAttributedString(string: "!"))

    #expect(try adjustedRange(of: "Hello", in: attrString) == "Hello") // no adjustment
    #expect(try adjustedRange(of: "!", in: attrString) == "!") // no adjustment
    #expect(try adjustedRange(of: "World", in: attrString) == "World") // no adjustment
    #expect(try adjustedRange(of: "Wor", in: attrString) == "World")
    #expect(try adjustedRange(of: "Hello Wor", in: attrString) == "Hello World")
    #expect(try adjustedRange(of: "Hello World!", in: attrString) == "Hello World!")
  }

  @Test
  func test_at_triggersSearch() async throws {
    let attrString = NSMutableAttributedString()
    attrString.append(NSAttributedString(string: "@"))
    let searchRange = try #require(attrString.searchRange(from: NSRange(location: 1, length: 0)))
    let searchQuery = attrString.attributedSubstring(from: searchRange).string
    #expect(searchQuery == "@")
  }

  @Test
  func test_searchRange_afterTextBlock() throws {
    let attrString = NSMutableAttributedString()
    attrString.append(NSAttributedString(string: "Hello "))
    attrString.append(NSAttributedString(string: "World", attributes: [
      .lockedAttributes: [
        NSAttributedString.Key.foregroundColor,
        NSAttributedString.Key.backgroundColor,
      ],
      .textBlock: UUID().uuidString,
    ]))
    attrString.append(NSAttributedString(string: " !@searchQuery hello"))

    #expect(try searchQuery(after: "Hello", in: attrString) == nil) // selection before `@`, before text block, no search
    #expect(try searchQuery(after: "Worl", in: attrString) == nil) // selection in text block, no search
    #expect(try searchQuery(after: "Hello World ", in: attrString) == nil) // selection before `@`, no search
    #expect(try searchQuery(after: "Hello World !@", in: attrString) ==
      "@searchQuery") // selection at `@`, search triggered up to next whitespace
    #expect(
      try searchQuery(after: "Hello World !@sear", in: attrString) ==
        "@searchQuery") // selection after `@`, search triggered up to next whitespace
    #expect(
      try searchQuery(after: "searchQuery hel", in: attrString) ==
        nil) // selection after `@` and a whitespace, no result
  }

  @Test
  func test_searchRange_withTextBlockMultilinesMultiSearches() throws {
    let attrString = NSMutableAttributedString()
    attrString.append(NSAttributedString(string: "Hello "))
    attrString.append(NSAttributedString(string: "World", attributes: [
      .lockedAttributes: [
        NSAttributedString.Key.foregroundColor,
        NSAttributedString.Key.backgroundColor,
      ],
      .textBlock: UUID().uuidString,
    ]))
    attrString.append(NSAttributedString(string: "! @search1\n@search2"))
    attrString.append(NSAttributedString(string: "Text\nBlock", attributes: [
      .lockedAttributes: [
        NSAttributedString.Key.foregroundColor,
        NSAttributedString.Key.backgroundColor,
      ],
      .textBlock: UUID().uuidString,
    ]))
    attrString.append(NSAttributedString(string: "\n @search3"))

    #expect(try searchQuery(after: "Hello", in: attrString) == nil) // selection before `@`, before text block, no search
    #expect(try searchQuery(after: "Worl", in: attrString) == nil) // selection in text block, no search
    #expect(try searchQuery(after: "Hello World", in: attrString) == nil) // selection before `@`, no search
    #expect(try searchQuery(after: "Hello World! @", in: attrString) == "@search1") // selection at `@`, search triggered
    #expect(try searchQuery(after: "Hello World! @sear", in: attrString) == "@search1") // selection after `@`, search triggered
    #expect(try searchQuery(after: "@search1\n@sea", in: attrString) == "@search2") // selection after `@`, search triggered
    #expect(try searchQuery(after: "Block\n @sea", in: attrString) == "@search3") // selection after `@`, search triggered
  }

  @Test
  func test_multipleAtsInSameLine() throws {
    let attrString = NSMutableAttributedString()
    attrString.append(NSAttributedString(string: "text with @FirstReference and more text @SecondReference"))
    #expect(try searchQuery(after: "SecondReference", in: attrString) == "@SecondReference")
  }

  private func adjustedRange(of pattern: String, in attrString: NSAttributedString) throws -> String {
    let string = attrString.string
    let range = try #require(string.range(of: pattern))
    let newRange = NSRange(range, in: string)
    let oldRange = NSRange(location: newRange.lowerBound, length: 0)
    let adjustedRange = attrString.adjustedTextBlockRangeOnSelectionChange(oldRange: oldRange, newRange: newRange) ?? newRange
    return attrString.attributedSubstring(from: adjustedRange).string
  }

  private func searchQuery(after pattern: String, in attrString: NSAttributedString, selectionLength: Int = 0) throws -> String? {
    let string = attrString.string
    let range = try #require(string.range(of: pattern))
    let selection = NSRange(location: NSRange(range, in: string).endLocation, length: selectionLength)
    if let searchRange = attrString.searchRange(from: selection) {
      return attrString.attributedSubstring(from: searchRange).string
    } else {
      return nil
    }
  }
}
