// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffTypesFoundation
import Foundation
import Testing
@testable import FileDiffFoundation

@Suite("Character-level diff parsing")
struct CharacterDiffToLineChangesTests {
  @Test("Simple change")
  func simpleChange() throws {
    let oldContent = "Hello World"
    let newContent = "Hello Swift"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

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
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

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
    let lineChanges = FileDiff.characterDiffToLineChanges(diff: diff).lineChanges

    // When there's no diff, git returns empty string
    // So we should get an empty or single line result
    #expect(lineChanges.count <= 1)
  }

  @Test("Addition only")
  func additionOnly() throws {
    let oldContent = "Hello"
    let newContent = "Hello World"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

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
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

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
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 1)
    let firstLine = try #require(lineChanges.first)

    let addedChars = firstLine.filter { $0.type == .added }
    #expect(addedChars.map(\.text).joined() == "Hello")
  }

  @Test("Change in the middle of a word")
  func changeInMiddleOfWord() throws {
    let oldContent = "Helo"
    let newContent = "Hello"

    let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

    #expect(firstDiffLine == 0)
    #expect(lineChanges.count == 1)
    let firstLine = try #require(lineChanges.first)

    let addedChars = firstLine.filter { $0.type == .added }
    #expect(addedChars.map(\.text).joined() == "l")
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
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

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
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

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
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

    #expect(firstDiffLine == 2)
    #expect(lineChanges.count == 2)
    #expect(lineChanges.first?.first?.type == .unchanged)
    #expect(lineChanges.first?.first?.text == "  print(\"Hello\")\n")
    #expect(lineChanges.last?.first?.type == .added)
    #expect(lineChanges.last?.first?.text == "  print(\"World\")\n")
  }

  @Test("Multiline change with only new lines")
  func multilineChangeWithOnlyNewLines() throws {
    let diff = """
      diff @@ -307,6 +307,10 @@ extension DefaultXcodeController {
          }
            #else
          guard let xcodeApp = getXcode(xcodeObserver: xcodeObserver, shellService: shellService) else {
      {+      defaultLogger.error("Could not find running Xcode")+}
      {+      throw AXError.cannotComplete+}
      {+    }+}
      {+      #endif+}

          if needToActivateXcode {
            if !xcodeApp.activate() {
      firstDiffLine 309
      """
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

    #expect(firstDiffLine == 309)
    #expect(lineChanges.count == 5)
  }

  @Test("Parse content with + sign")
  func parseContentWithPlusSign() {
    let diff = """
      diff @@ -93,5 +93,7 @@ struct CompletionDiffView: View {
          }
        }
          private func add(a: Int, b: Int) -> Int {
      {+        return a + b+}
      {+    }+}
      }
      """
    let (lineChanges, firstDiffLine) = FileDiff.characterDiffToLineChanges(diff: diff)

    #expect(firstDiffLine == 95)
    #expect(lineChanges.first?.count == 1)
    #expect(lineChanges[1].first?.type == .added)
    #expect(lineChanges[1].first?.text == "        return a + b\n")
  }
}
