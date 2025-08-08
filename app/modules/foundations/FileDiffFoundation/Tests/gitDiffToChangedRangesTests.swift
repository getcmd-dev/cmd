// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffTypesFoundation
import Testing
@testable import FileDiffFoundation

struct GitDiffToChangedRangesTests {

  @Test
  func testNoChanges() throws {
    let old = """
      print("Hello")
      print("No changes here")
      """
    let new = """
      print("Hello")
      print("No changes here")
      """
    try validateDiffRanges(from: old, to: new, expectedRangeCount: 2)
  }

  @Test
  func testPureAdditions() throws {
    let old = """
      func greet() {

        print("Hello")
      }
      """
    let new = """
      /// This function greets the user

      /// by printing "Hello"
      func greet() {

        print("Hello")
      }

      // End-of-file note
      """
    try validateDiffRanges(from: old, to: new, expectedRangeCount: 10)
  }

  @Test
  func testPureAdditionsInMiddleOfFile() throws {
    let old = """
      func greet() {
        print("Hello")
      }
      """
    let new = """
      func greet() {
        // Say something
        print("Hello")
      }
      """
    try validateDiffRanges(from: old, to: new, expectedRangeCount: 4)

    let diff = try FileDiff.getGitDiff(oldContent: old, newContent: new)
    let ranges = FileDiff.gitDiffToChangedRanges(oldContent: old, newContent: new, diffText: diff)
    #expect(ranges[1].type == .added)
    #expect(new.substring(ranges[1].characterRange) == "  // Say something\n")
  }

  @Test
  func testPureRemovals() throws {
    let old = """
      let foo = 10
      let bar = 20
      print("Done")
      """
    let new = """
      let foo = 10
      print("Done")
      """
    try validateDiffRanges(from: old, to: new, expectedRangeCount: 3)
  }

  @Test
  func testSingleInlineReplacement() throws {
    let old = """
      print("Hello World")
      print("Line Two")
      """
    let new = """
      print("Hello Earth")
      print("Line Two")
      """
    try validateDiffRanges(from: old, to: new, expectedRangeCount: 3)
  }

  @Test
  func testIdenticalReplacement() throws {
    let old = """
      func doSomething() {
        let x = "test"
        print(x)
      }
      """
    let new = """
      func doSomething() {
        let x = "test"
        print(x)
      }
      """
    // Even though no net difference, a naive diff could show [-test-]{+test+}.
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testMultipleInlineReplacementsOneLine() throws {
    let old = """
      print("One, Two, Three, Four, Five")
      """
    let new = """
      print("1, 2, 3, 4, 5")
      """
    try validateDiffRanges(from: old, to: new, expectedRangeCount: 2)
  }

  @Test
  func testAddedAndReplacedLines() throws {
    let old = """
      class MyClass {
        func sayHi() {
          print("Hi")
        }
      }
      """
    let new = """
      class MyClass {
        // This function says hello
        func sayHello() {
          print("Hello")
        }

        // Additional method
        func sayBye() {
          print("Bye")
        }
      }
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testReplacementOfEntireBlock() throws {
    let old = """
      if conditionA {
        doThingA()
      } else {
        doThingB()
      }
      """
    let new = """
      if conditionX {
        doThingX()
      } else if conditionY {
        doThingY()
      } else {
        doThingB()
      }
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testMixedContentTrailingNewline() throws {
    let old = """
      Line 1
      Line 2
      Line 3
      """ // no trailing newline

    let new = """
      Line 1
      Line 2.5
      Line 2
      Line 3

      """ // has a trailing newline
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testEmptyOldFile() throws {
    let old = "" // empty
    let new = """
      print("New file!")
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testChangeAtEndOfFile() throws {
    let old = """
      func main() {
        setup()
        process()
        cleanup()
      }
      """
    let new = """
      func main() {
        setup()
        process()
        cleanup()
        logCompletion()
      }
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testWidelySeparatedChanges() throws {
    let old = """
      // Configuration
      let config = Config()

      // ... many lines in between ...
      func process() {
        doWork()
      }

      // ... more lines ...
      let result = "done"
      """
    let new = """
      // Updated Configuration
      let config = AdvancedConfig()

      // ... many lines in between ...
      func process() {
        doAdvancedWork()
      }

      // ... more lines ...
      let result = "completed"
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testChangesWithSpecialCharacters() throws {
    let old = """
      let regex = "\\w+\\s*"
      let path = "C:\\Program Files"
      """
    let new = """
      let regex = "\\w+\\s*\\d+"
      let path = "D:\\Program Files"
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testMultipleNewlines() throws {
    let old = """
      line1

      line2
      """
    let new = """
      line1



      line2
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testOverlappingChanges() throws {
    let old = """
      func process() {
        step1()
        step2()
        step3()
      }
      """
    let new = """
      func newProcess() {
        newStep1()
        // step2 removed
        newStep3()
      }
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testLinesStartingWithDiffMarkers() throws {
    let old = """
      let operations = [
        "+ Addition",
        "- Subtraction",
        "+++ Increment",
        "--- Decrement"
      ]
      """
    let new = """
      let operations = [
        "+ Addition",
        "- Subtraction",
        "++ Double increment",
        "-- Double decrement"
      ]
      """
    try validateDiffRanges(from: old, to: new)
  }

  @Test
  func testAdditionInCode() throws {
    let old = """
      struct CodePreview: View {
        let filePath: URL
        let fileContent: String
        let startLine: Int?
        let endLine: Int?

        var body: some View {
          Text(content)
        }
      }
      """
    let new = """
      struct CodePreview: View {
        let filePath: URL
        // The content of the file 
        let fileContent: String
        let startLine: Int?
        let endLine: Int?

        var body: some View {
          Text(content)
        }
      }
      """
    let ranges = try validateDiffRanges(from: old, to: new)
    #expect(ranges.count == 11)
  }

  @Test
  func testSeveralDiffSegments() throws {
    let old = """
      // 1
      // 2
      // 3
      // 4
      // 5
      // 6
      // 7
      // 8
      // 9
      // 10.5
      // 11
      // 12
      // 13
      """
    let new = """
      // 1
      // 2
      // 2.5
      // 3
      // 4
      // 5
      // 6
      // 7
      // 8
      // 9
      // 10
      // 11
      // 12
      // 13
      """

    let diff = try FileDiff.getGitDiff(oldContent: old, newContent: new)
    #expect(diff.split(separator: "@@\n").count == 3) // Validate that the diff has 2 (3 - 1) segments.
    try validateDiffRanges(from: old, to: new)
  }

  @Test("real world example")
  func testRealWorldExample() async throws {
    // Given
    let old = """
      //
      //
      // Those are the interface for all the atomic APIs.
      // An example of a non atomic API call is sending a message with tool call:
      //   User send message ->
      //                  <- Assistant call tool
      //   User send tool input ->
      //                  <- Assistant send response
      //
      // Here the client sends two atomic API calls to the server.

      import Foundation

      // MARK: - Tool

      /// A tool that can be called by the assistant.
      public protocol Tool: Encodable, Sendable {
        func use(input: JSON) async throws -> JSON
        var name: String { get }
        var description: String { get }
        var inputSchema: JSON { get }
      }

      // MARK: - LLMModel

      public struct LLMModel: Hashable, Identifiable, CaseIterable, Sendable {
        public static var allCases: [LLMModel] {
          [.claudeSonnet, .gpt4o, .gpt4o_mini, .o1]
        }

        public let displayName: String
        public let id: String

        public static let claudeSonnet = LLMModel(displayName: "claude-3.7-sonnet", id: "claude-3-7-sonnet-latest")
        public static let gpt4o = LLMModel(displayName: "gpt-latest", id: "gpt-latest")
        public static let gpt4o_mini = LLMModel(displayName: "gpt-latest-mini", id: "gpt-latest-mini")
        public static let o1 = LLMModel(displayName: "o1", id: "o1-preview")
      }

      """
    let llmDiff = """
      <<<<<<< SEARCH
      // MARK: - Tool

      /// A tool that can be called by the assistant.
      public protocol Tool: Encodable, Sendable {
        func use(input: JSON) async throws -> JSON
        var name: String { get }
        var description: String { get }
        var inputSchema: JSON { get }
      }
      =======
      // MARK: - Tool

      /// A tool that can be called by the assistant.
      public protocol Tool: Encodable, Sendable {
        /// Executes the tool with the provided input and returns the result
        /// - Parameter input: JSON data containing the tool's input parameters
        /// - Returns: JSON data containing the tool's output
        /// - Throws: Any errors that occur during tool execution
        func use(input: JSON) async throws -> JSON

        /// The name of the tool
        var name: String { get }

        /// A description of what the tool does and how to use it
        var description: String { get }

        /// JSON schema defining the structure and validation rules for the tool's input
        var inputSchema: JSON { get }
      }
      >>>>>>> REPLACE

      <<<<<<< SEARCH
      // MARK: - LLMModel

      public struct LLMModel: Hashable, Identifiable, CaseIterable, Sendable {
        public static var allCases: [LLMModel] {
          [.claudeSonnet, .gpt4o, .gpt4o_mini, .o1]
        }

        public let displayName: String
        public let id: String
      =======
      // MARK: - LLMModel

      /// Represents a Large Language Model available for use in the application
      public struct LLMModel: Hashable, Identifiable, CaseIterable, Sendable {
        /// All available LLM models in the application
        public static var allCases: [LLMModel] {
          [.claudeSonnet, .gpt4o, .gpt4o_mini, .o1]
        }

        /// The user-friendly display name of the model
        public let displayName: String

        /// The unique identifier for the model used in API requests
        public let id: String
      >>>>>>> REPLACE

      <<<<<<< SEARCH
        public static let claudeSonnet = LLMModel(displayName: "claude-3.7-sonnet", id: "claude-3-7-sonnet-latest")
        public static let gpt4o = LLMModel(displayName: "gpt-latest", id: "gpt-latest")
        public static let gpt4o_mini = LLMModel(displayName: "gpt-latest-mini", id: "gpt-latest-mini")
        public static let o1 = LLMModel(displayName: "o1", id: "o1-preview")
      =======
        /// Claude 3.7 Sonnet model by Anthropic
        public static let claudeSonnet = LLMModel(displayName: "claude-3.7-sonnet", id: "claude-3-7-sonnet-latest")

        /// gpt-latest model by OpenAI
        public static let gpt4o = LLMModel(displayName: "gpt-latest", id: "gpt-latest")

        /// gpt-latest-mini model by OpenAI
        public static let gpt4o_mini = LLMModel(displayName: "gpt-latest-mini", id: "gpt-latest-mini")

        /// o1 preview model by Deepmind
        public static let o1 = LLMModel(displayName: "o1", id: "o1-preview")
      >>>>>>> REPLACE
      """
    let new = try FileDiff.apply(searchReplacePattern: llmDiff, to: old)

    let ranges = try validateDiffRanges(from: old, to: new)
    #expect(ranges.count == 61)
  }

  @Test("real world example 2")
  func test_realWorldExample2() throws {
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

  @discardableResult
  private func validateDiffRanges(
    from oldContent: String,
    to newContent: String,
    expectedRangeCount: Int? = nil)
    throws -> [LineChange]
  {
    let diff = try FileDiff.getGitDiff(oldContent: oldContent, newContent: newContent)
    let ranges = FileDiff.gitDiffToChangedRanges(oldContent: oldContent, newContent: newContent, diffText: diff)

    if let expectedRangeCount {
      #expect(ranges.count == expectedRangeCount)
    }

    var previousTextFromRanges = ""
    var newTextFromRanges = ""

    for piece in ranges {
      switch piece.type {
      case .removed:
        let start = oldContent.index(oldContent.startIndex, offsetBy: piece.characterRange.lowerBound)
        let end = oldContent.index(oldContent.startIndex, offsetBy: piece.characterRange.upperBound)
        previousTextFromRanges += oldContent[start..<end]

      case .added:
        let start = newContent.index(newContent.startIndex, offsetBy: piece.characterRange.lowerBound)
        let end = newContent.index(newContent.startIndex, offsetBy: piece.characterRange.upperBound)
        newTextFromRanges += newContent[start..<end]

      case .unchanged:
        let start = newContent.index(newContent.startIndex, offsetBy: piece.characterRange.lowerBound)
        let end = newContent.index(newContent.startIndex, offsetBy: piece.characterRange.upperBound)
        newTextFromRanges += newContent[start..<end]
        previousTextFromRanges += newContent[start..<end]
      }
    }

    #expect(newTextFromRanges == newContent)
    #expect(previousTextFromRanges == oldContent)

    return ranges
  }
}
