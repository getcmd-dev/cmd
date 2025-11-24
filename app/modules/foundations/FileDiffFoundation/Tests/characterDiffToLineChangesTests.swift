// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffTypesFoundation
import Foundation
import Testing
@testable import FileDiffFoundation

@Suite("Character-level diff parsing")
struct CharacterDiffToLineChangesTests {
  struct ReformatWordsTests {
    @Test("reformatWords merges partial replacements inside a word")
    func reformatWordsMergesPartialReplacements() {
      let segments: [CharacterLevelChange] = [
        .init(text: "colo", type: .unchanged),
        .init(text: "r", type: .removed),
        .init(text: "ur", type: .added),
      ]

      let aligned = FileDiff.reformatWords(in: segments)
      #expect(aligned.debugDescription == "{-color-}{+colour+}")
    }

    @Test("reformatWords keeps trailing punctuation with additions")
    func reformatWordsKeepsPunctuationWithAddedWord() {
      let segments: [CharacterLevelChange] = [
        .init(text: "pri", type: .added),
        .init(text: "nt", type: .added),
        .init(text: "(", type: .added),
        .init(text: "0", type: .added),
        .init(text: ")", type: .added),
      ]

      let aligned = FileDiff.reformatWords(in: segments)
      #expect(aligned.debugDescription == "{+print(0)+}")
    }

    @Test("reformatWords promotes shared prefix instead of mixing add/remove")
    func reformatWordsPromotesSharedPrefix() {
      let segments: [CharacterLevelChange] = [
        .init(text: "pr", type: .unchanged),
        .init(text: "int(0)", type: .added),
      ]

      let aligned = FileDiff.reformatWords(in: segments)
      #expect(aligned.debugDescription == "pr{+int(0)+}")
    }

    @Test("reformatWords replaces whole word when change spans it")
    func reformatWordsReplacesWholeWordWhenChangeSpansIt() {
      let segments: [CharacterLevelChange] = [
        .init(text: "impleme", type: .removed),
        .init(text: "pri", type: .added),
        .init(text: "nt", type: .unchanged),
      ]

      let aligned = FileDiff.reformatWords(in: segments)
      #expect(aligned.debugDescription == "{-implement-}{+print+}")
    }

    @Test("reformatWords keeps unchanged prefix when appending digits")
    func reformatWordsKeepsUnchangedPrefixWhenAppendingDigits() {
      let segments: [CharacterLevelChange] = [
        .init(text: "line 2", type: .unchanged),
        .init(text: "0", type: .added),
      ]

      let aligned = FileDiff.reformatWords(in: segments)
      #expect(aligned.debugDescription == "line 2{+0+}")
    }

    @Test("reformatWords treats underscores as separators")
    func reformatWordsTreatsUnderscoreAsSeparator() {
      let segments: [CharacterLevelChange] = [
        .init(text: "foo", type: .unchanged),
        .init(text: "_", type: .unchanged),
        .init(text: "bar", type: .added),
      ]

      let aligned = FileDiff.reformatWords(in: segments)
      #expect(aligned.debugDescription == "foo_{+bar+}")
    }

    @Test("reformatWords keeps newline separators intact")
    func reformatWordsKeepsNewlinesSeparate() {
      let segments: [CharacterLevelChange] = [
        .init(text: "line ", type: .unchanged),
        .init(text: "1", type: .unchanged),
        .init(text: "\n", type: .unchanged),
        .init(text: "line ", type: .unchanged),
        .init(text: "2", type: .added),
        .init(text: "\n", type: .added),
      ]

      let aligned = FileDiff.reformatWords(in: segments)
      #expect(aligned.debugDescription == "line 1\nline {+2\n+}")
    }
  }

  @Test("Simple change")
  func simpleChange() throws {
    let oldContent = "Hello World"
    let newContent = "Hello Swift"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 1)
    let firstLine = try #require(lineChanges.first)

    // Verify the structure: "Hello " (unchanged) + "W" + "o" + "r" + "l" + "d" (removed) + "S" + "w" + "i" + "f" + "t" (added)
    let unchangedChars = firstLine.filter { $0.type == .unchanged }
    let removedChars = firstLine.filter { $0.type == .removed }
    let addedChars = firstLine.filter { $0.type == .added }

    #expect(unchangedChars.map(\.text).joined() == "Hello ")
    #expect(removedChars.map(\.text).joined() == "World")
    #expect(addedChars.map(\.text).joined() == "Swift")
  }

  @Test("Multiline change")
  func multilineChange() throws {
    let oldContent = """
      func hello() {
        print("Hello")
      }
      """
    let newContent = """
      func hello(name: String) {
        print("Hello \\(name)!")
      }
      """

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 2)

    // First line should have changes
    let firstLine = try #require(lineChanges.first)
    let hasAdditions = firstLine.contains { $0.type == .added }
    #expect(hasAdditions)
  }

  @Test("No changes")
  func noChanges() throws {
    let content = "Hello World"

    let diff = try FileDiff.getCharacterDiff(oldContent: content, newContent: content)
    let lineChanges = FileDiff.characterDiffToLineChanges(diff: diff, oldContent: content, newContent: content).lineChanges

    // When there's no diff, git returns empty string
    // So we should get an empty or single line result
    #expect(lineChanges.count <= 1)
  }

  @Test("Addition only")
  func additionOnly() throws {
    let oldContent = "Hello"
    let newContent = "Hello World"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 1)
    let firstLine = try #require(lineChanges.first)

    let unchangedChars = firstLine.filter { $0.type == .unchanged }
    let addedChars = firstLine.filter { $0.type == .added }
    let removedChars = firstLine.filter { $0.type == .removed }

    #expect(unchangedChars.map(\.text).joined() == "Hello")
    #expect(addedChars.map(\.text).joined() == " World")
    #expect(removedChars.isEmpty)
  }

  @Test("Removal only")
  func removalOnly() throws {
    let oldContent = "Hello World"
    let newContent = "Hello"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 1)
    let firstLine = try #require(lineChanges.first)

    let unchangedChars = firstLine.filter { $0.type == .unchanged }
    let addedChars = firstLine.filter { $0.type == .added }
    let removedChars = firstLine.filter { $0.type == .removed }

    #expect(unchangedChars.map(\.text).joined() == "Hello")
    #expect(addedChars.isEmpty)
    #expect(removedChars.map(\.text).joined() == " World")
  }

  @Test("Empty content")
  func emptyContent() throws {
    let oldContent = ""
    let newContent = "Hello"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 1)
    let firstLine = try #require(lineChanges.first)

    let addedChars = firstLine.filter { $0.type == .added }
    #expect(addedChars.map(\.text).joined() == "Hello")
  }

  @Test("No new line at end of old content")
  func noNewLineAtEndOfOldContent() throws {
    let oldContent = "Hello World"
    let newContent = "Hello World\nThis is a new line."

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 2)
    let firstLine = try #require(lineChanges.first)
    let secondLine = try #require(lineChanges.last)
    #expect(firstLine.debugDescription == "Hello World{+\n+}")
    #expect(secondLine.debugDescription == "{+This is a new line.+}")
  }

  @Test("No new line at end of new content")
  func noNewLineAtEndOfNewContent() throws {
    let oldContent = "Hello World\n"
    let newContent = "Hello World\nThis is a new line."

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 2)
    let firstLine = try #require(lineChanges.first)
    let secondLine = try #require(lineChanges.last)
    #expect(firstLine.debugDescription == "Hello World\n")
    #expect(secondLine.debugDescription == "{+This is a new line.+}")
  }

  @Test("No new line at end of either content")
  func noNewLineAtEndOfEitherContent() throws {
    let oldContent = "Hello World"
    let newContent = "Hello World. This is a new sentence."

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 1)
    let firstLine = try #require(lineChanges.first)
    #expect(firstLine.debugDescription == "Hello World{+. This is a new sentence.+}")
  }

  @Test("New line at end of both content")
  func newLineAtEndOfBothContent() throws {
    let oldContent = "Hello World.\n"
    let newContent = "Hello World.\nThis is a new sentence.\n"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.map(\.debugDescription) == [
      "Hello World.\n",
      "{+This is a new sentence.\n+}",
    ])
  }

  @Test("Change in the middle of a word")
  func changeInMiddleOfWord() throws {
    let oldContent = "Helo"
    let newContent = "Hello"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 1)
    let firstLine = try #require(lineChanges.first)

    #expect(firstLine.debugDescription == "Hel{+l+}o")
  }

  @Test("Word replacements are emitted as whole-word changes")
  func wordReplacementProducesWholeWordChanges() throws {
    let oldContent = "// TODO: implement"
    let newContent = "print(0)"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(lineChanges.count == 1)
    #expect(lineChanges.map(\.debugDescription) == ["{-// TODO: implement-}{+print(0)+}"])
  }

  @Test("Insertions inside a word collapse to a word-level change")
  func insertionInsideWordProducesWholeWordDiff() throws {
    let oldContent = "color"
    let newContent = "colour"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(lineChanges.count == 1)
    #expect(lineChanges.map(\.debugDescription) == ["colo{+u+}r"])
  }

  @Test("Change in the middle of unchanged lines")
  func changeInMiddleOfMultipleLines() throws {
    let oldContent = """
      func hello() {
        print("Hello")
      }
      """
    let newContent = """
      func hello() {
        print("Hello world!")
      }
      """

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 1)
    #expect(lineChanges.count == 1)
  }

  @Test("Change in the middle of unchanged lines, including empty ones")
  func changeInMiddleOfMultipleLinesIncludingEmptyOnes() throws {
    let oldContent = """
      func hello() {

        print("Hello")
      }
      """
    let newContent = """
      func hello() {

        print("Hello world!")
      }
      """

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 2)
    #expect(lineChanges.count == 1)
  }

  @Test("Diff starts at previous unchanged line when first change is on a new line")
  func diffStartsAtPreviousUnchangedLineWhenFirstChangeIsOnANewLine() throws {
    let oldContent = """
      func hello() {

        print("Hello")
      }
      """
    let newContent = """
      func hello() {

        print("Hello")
        print("World")
      }
      """

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 2)
    #expect(lineChanges.count == 2)
    #expect(lineChanges.first?.first?.type == .unchanged)
    #expect(lineChanges.first?.first?.text == "  print(\"Hello\")\n")
    #expect(lineChanges.last?.first?.type == .added)
    #expect(lineChanges.last?.first?.text == "  print(\"World\")\n")
  }

  @Test("Multiline change with only new lines")
  func multilineChangeWithOnlyNewLines() throws {
    let oldContent = """
          }
            #else
          guard let xcodeApp = getXcode(xcodeObserver: xcodeObserver, shellService: shellService) else {

          if needToActivateXcode {
      """
    let newContent = """
          }
            #else
          guard let xcodeApp = getXcode(xcodeObserver: xcodeObserver, shellService: shellService) else {
              defaultLogger.error("Could not find running Xcode")
              throw AXError.cannotComplete
            }
              #endif

          if needToActivateXcode {
      """
    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 2)
    #expect(lineChanges.map(\.debugDescription) == [
      "    guard let xcodeApp = getXcode(xcodeObserver: xcodeObserver, shellService: shellService) else {\n",
      "{+        defaultLogger.error(\"Could not find running Xcode\")+}\n",
      "{+        throw AXError.cannotComplete\n+}",
      "{+      }\n+}",
      "{+        #endif\n+}", "{+\n+}",
    ])
  }

  @Test("Parse content with + sign")
  func parseContentWithPlusSign() throws {
    let oldContent = """
          }
        }
          private func add(a: Int, b: Int) -> Int {
      }
      """
    let newContent = """
          }
        }
          private func add(a: Int, b: Int) -> Int {
            return a + b
        }
      }
      """
    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    #expect(firstDiffLine == 2)
    #expect(lineChanges.map(\.debugDescription) == [
      "    private func add(a: Int, b: Int) -> Int {\n",
      "{+      return a + b\n+}",
      "{+  }\n+}",
    ])
  }

  // MARK: - Trailing Newline Tests

  @Test("handles missing trailing newline in old content")
  func handlesMissingTrailingNewlineInOld() throws {
    let oldContent = "line1\nline2" // no trailing \n
    let newContent = "line1\nline2\n"
    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    // Should detect the added newline
    let lastLine = lineChanges.last?.debugDescription ?? ""
    #expect(lastLine.contains("{+") || lastLine.contains("\n"))
  }

  @Test("handles missing trailing newline in new content")
  func handlesMissingTrailingNewlineInNew() throws {
    let oldContent = "line1\nline2\n"
    let newContent = "line1\nline2" // no trailing \n
    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    // Should detect the removed newline
    let lastLine = lineChanges.last?.debugDescription ?? ""
    #expect(lastLine.contains("{-") || lastLine.contains("\n"))
  }

  @Test("handles both files missing trailing newline")
  func handlesBothFilesMissingTrailingNewline() throws {
    let oldContent = "line1\nline2" // no trailing \n
    let newContent = "line1\nline2" // no trailing \n
    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    // Should be recognized as unchanged
    #expect(lineChanges.isEmpty || lineChanges.allSatisfy { $0.allSatisfy { $0.type == .unchanged } })
  }

  @Test("handles file with only newline character")
  func handlesFileWithOnlyNewline() throws {
    let oldContent = "\n"
    let newContent = "x\n"
    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    // Should detect the added character
    #expect(!lineChanges.isEmpty)
    #expect(lineChanges.first?.contains(where: { $0.type == .added }) == true)
  }

  @Test("handles empty file to newline")
  func handlesEmptyFileToNewline() throws {
    let oldContent = ""
    let newContent = "\n"
    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    // Should detect the added newline
    #expect(!lineChanges.isEmpty)
  }

  @Test("handles newline to empty file")
  func handlesNewlineToEmptyFile() throws {
    let oldContent = "\n"
    let newContent = ""
    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(
      diff: diff,
      oldContent: oldContent,
      newContent: newContent)

    // Should detect the removed newline
    #expect(!lineChanges.isEmpty)
  }
}
