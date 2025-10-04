// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import JSONFoundation
import LocalServerServiceInterface
import SwiftTesting
import Testing
@testable import SearchFilesTool

// MARK: - ClaudeCodeGrepToolTests

struct ClaudeCodeGrepToolTests {

  let mockInput = try! JSONDecoder().decode(ClaudeCodeGrepInput.self, from: """
    {
      "pattern": "JSON",
      "output_mode": "files_with_matches",
      "projectRoot": "/me/cmd/app"
    }
    """.utf8Data)

  @Test
  func handlesExternalOutputCorrectly() async throws {
    let toolUse = ClaudeCodeGrepTool().use(
      toolUseId: "123",
      input: mockInput,
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/me/cmd/app")))

    toolUse.startExecuting()

    let testOutput = """
      Found 8 files
      /serviceInterfaces/LocalServerServiceInterface/Sources/sendMessageSchema.generated.swift
      /services/ChatHistoryService/Sources/Serialization.swift
      /foundations/JSONFoundation/Sources/JSON.swift
      /foundations/LLMFoundation/Sources/AIProvider.swift
      /services/LLMService/Sources/JSON+partialParsing.swift
      /services/ChatHistoryService/Sources/AttachmentSerializer.swift
      /serviceInterfaces/LocalServerServiceInterface/Tests/ErrorParsingTests.swift
      /foundations/ToolFoundation/Sources/Encoding.swift
      """
    try toolUse.receive(output: .string(testOutput))
    let results = try await toolUse.output.results
    #expect(results.map(\.path) == [
      "/serviceInterfaces/LocalServerServiceInterface/Sources/sendMessageSchema.generated.swift",
      "/services/ChatHistoryService/Sources/Serialization.swift",
      "/foundations/JSONFoundation/Sources/JSON.swift",
      "/foundations/LLMFoundation/Sources/AIProvider.swift",
      "/services/LLMService/Sources/JSON+partialParsing.swift",
      "/services/ChatHistoryService/Sources/AttachmentSerializer.swift",
      "/serviceInterfaces/LocalServerServiceInterface/Tests/ErrorParsingTests.swift",
      "/foundations/ToolFoundation/Sources/Encoding.swift",
    ])
  }

  @Test
  func handlesExternalOutputWithContextCorrectly() async throws {
    let toolUse = ClaudeCodeGrepTool().use(
      toolUseId: "123",
      input: mockInput,
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/me/cmd/app")))

    toolUse.startExecuting()
    let outputWithoutLineNumber = """
      /features/Chat/ChatFeature/Sources/ChatCompletion/ChatViewModel+ChatCompletionServiceDelegate.swift-    thread.input.selectedModel = AIModel.allTestCases.first { $0.name == chatCompletion.modelName }
      /features/Chat/ChatFeature/Sources/ChatCompletion/ChatViewModel+ChatCompletionServiceDelegate.swift:    @Dependency(\\.xcodeObserver) var xcodeObserver
      /features/Chat/ChatFeature/Sources/ChatCompletion/ChatViewModel+ChatCompletionServiceDelegate.swift:    let projectRoot = xcodeObserver.state.focusedWorkspace?.url
      /features/Chat/ChatFeature/Sources/ChatCompletion/ChatViewModel+ChatCompletionServiceDelegate.swift-
      """
    try toolUse.receive(output: .string(outputWithoutLineNumber))
    let results = try await toolUse.output.results

    #expect(results.map(\.path) == [
      "/features/Chat/ChatFeature/Sources/ChatCompletion/ChatViewModel+ChatCompletionServiceDelegate.swift",
    ])

    #expect(results.map(\.searchResults) == [
      [
        [0, "    @Dependency(\\.xcodeObserver) var xcodeObserver", true],
        [0, "    let projectRoot = xcodeObserver.state.focusedWorkspace?.url", true],
      ],
    ])
  }

  @Test
  func handlesExternalOutputWithContextLineNumberCorrectly() async throws {
    let toolUse = ClaudeCodeGrepTool().use(
      toolUseId: "123",
      input: mockInput,
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/me/cmd/app")))

    toolUse.startExecuting()
    let outputWithLineNumber = """
      /plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift-152-      input: mappedInput,
      /plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift-153-      isInputComplete: true,
      /plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift:154:      setResult: { _ in },
      /plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift-155-      context: context)
      /plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift-156-
      --
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-30-    input: [EditFilesTool.Use.FileChange],
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-31-    isInputComplete: Bool,
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift:32:    setResult: @escaping (EditFilesTool.Use.FormattedOutput) -> Void,
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-33-    toolUseResult: EditFilesTool.Use.FormattedOutput = .init(fileChanges: []),
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-34-    context: ToolExecutionContext)
      --
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-37-    self.input = input
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-38-    self.isInputComplete = isInputComplete
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift:39:    self.setResult = setResult
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-40-    self.toolUseResult = toolUseResult
      /plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-41-    self.context = context
      """
    try toolUse.receive(output: .string(outputWithLineNumber))
    let results = try await toolUse.output.results

    #expect(results.map(\.path) == [
      "/plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift",
      "/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift",
    ])
    #expect(results.map(\.searchResults) == [
      [
        [154, "      setResult: { _ in },", true],
      ], [
        [32, "    setResult: @escaping (EditFilesTool.Use.FormattedOutput) -> Void,", true],
        [39, "    self.setResult = setResult", true],
      ],
    ])
  }

  @Test
  func handlesEmptyOutputCorrectly() async throws {
    let toolUse = ClaudeCodeGrepTool().use(
      toolUseId: "123",
      input: mockInput,
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/me/cmd/app")))

    toolUse.startExecuting()

    try toolUse.receive(output: .string("No files found"))
    let result = try await toolUse.output.results.map(\.path)
    #expect(result == [])
  }
}

// MARK: - Schema.SearchResult + ExpressibleByArrayLiteral, Equatable

extension Schema.SearchResult: ExpressibleByArrayLiteral, Equatable {
  public init(arrayLiteral elements: ArrayLiteralElement...) {
    guard
      elements.count == 3,
      let line = elements[0] as? Int,
      let text = elements[1] as? String,
      let isMatch = elements[2] as? Bool
    else {
      fatalError("Invalid elements for array literal \(elements)")
    }
    self.init(line: line, text: text, isMatch: isMatch)
  }

  public typealias ArrayLiteralElement = Any

  public static func ==(lhs: Schema.SearchResult, rhs: Schema.SearchResult) -> Bool {
    lhs.line == rhs.line && lhs.text == rhs.text && lhs.isMatch == rhs.isMatch
  }

}
