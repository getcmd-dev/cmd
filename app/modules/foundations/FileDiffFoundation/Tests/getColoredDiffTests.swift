// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import FileDiffFoundation
import Foundation
@preconcurrency import SnapshotTesting
import SwiftUI
import Testing

// MARK: - GetColoredDiffTests

struct GetColoredDiffTests {
  @MainActor
  @Test("simple addition")
  func testSimpleAddition() async throws {
    // Given
    let previous = "func test() {\n}"
    let new = "func test() {\n    print(\"hello\")\n}"

    // When
    let diff = try await FileDiff.getColoredDiff(
      oldContent: previous,
      newContent: new,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @Test("simple removal")
  func testSimpleRemoval() async throws {
    // Given
    let previous = "func test() {\n    print(\"hello\")\n}"
    let new = "func test() {\n}"

    // When
    let diff = try await FileDiff.getColoredDiff(
      oldContent: previous,
      newContent: new,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @Test("multiple changes")
  func testMultipleChanges() async throws {
    // Given
    let previous = """
      func test() {
          print("old")
          let x = 1
      }
      """

    let new = """
      func test() {
          print("new")
          let y = 2
      }
      """

    // When
    let diff = try await FileDiff.getColoredDiff(
      oldContent: previous,
      newContent: new,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @Test("custom colors")
  func testCustomColors() async throws {
    // Given
    let previous = "let x = 1"
    let new = "let x = 2"

    // When
    let diff = try await FileDiff.getColoredDiff(
      oldContent: previous,
      newContent: new,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @Test("addition in code")
  func testAdditionInCode() async throws {
    let previous = """
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

    // When
    let diff = try await FileDiff.getColoredDiff(
      oldContent: previous,
      newContent: new,
      highlightColors: .light(.xcode))

    // Then
    #expect(diff.changes.count == 11)
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }

  @Test("real world example")
  func testRealWorldExample() async throws {
    // Given
    let previous = """

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
    let new = try FileDiff.apply(searchReplacePattern: llmDiff, to: previous)

    // When
    let diff = try await FileDiff.getColoredDiff(
      oldContent: previous,
      newContent: new,
      highlightColors: .light(.xcode))

    // Then
    try assertSnapshot(of: diff.toHTML(), as: .html)
  }
}

extension FormattedFileChange {
  fileprivate func toHTML() throws -> String {
    var formattedDiff = AttributedString(unicodeScalarLiteral: "")
    let addedBackground = NSColor.green.withAlphaComponent(0.2)
    let removedBackground = NSColor.red.withAlphaComponent(0.2)

    for formattedLineChange in changes {
      let lineChange = formattedLineChange.change
      switch lineChange.type {
      case .added:
        var addedString = formattedLineChange.formattedContent
        let container = AttributeContainer([
          .backgroundColor: addedBackground,
          .baselineOffset: 0,
        ])
        addedString.mergeAttributes(container)

        formattedDiff.insert(addedString, at: formattedDiff.endIndex)

      case .removed:
        var removedString = formattedLineChange.formattedContent
        let container = AttributeContainer([
          .backgroundColor: removedBackground,
          .baselineOffset: 0,
        ])
        removedString.mergeAttributes(container)

        formattedDiff.insert(removedString, at: formattedDiff.endIndex)

      case .unchanged:
        let unchangedString = formattedLineChange.formattedContent
        formattedDiff.insert(unchangedString, at: formattedDiff.endIndex)
      }
    }
    return try formattedDiff.toHTML()
  }
}

extension Snapshotting where Value == String, Format == String {
  public static let html = Snapshotting(pathExtension: "html", diffing: .lines)
}

// MARK: - RenderedDiff

private struct RenderedDiff: View {
  let diff: AttributedString
  var body: some View {
    Text(diff)
  }
}

extension AttributedString {

  func toHTML() throws -> String {
    let nsAttributedString = NSAttributedString(self)
    let documentAttributes = [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.html]

    let htmlData = try nsAttributedString.data(
      from: .init(location: 0, length: nsAttributedString.length),
      documentAttributes: documentAttributes)

    guard let html = String(data: htmlData, encoding: .utf8) else {
      throw NSError(
        domain: "HTMLConversionError",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to convert HTML data to string"])
    }

    return html
      // This tag will have a different value based on the MacOS version the code
      // is executed on, making the test flakey if not handled.
      .replacing(
        /<meta name="CocoaVersion" content="(?<version>\d+(\.\d+)?)">/,
        with: "<meta name=\"CocoaVersion\" content=\"CocoaVersion\">")
      // The `-webkit-text-stroke` attribute is not stable with CI, probably due to some version mismatch not worth going into.
      .replacing(
        /-webkit-text-stroke:[^;}]*(;|(?=}))/,
        with: "")
      .replacingOccurrences(of: "; }", with: "}")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
