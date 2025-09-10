// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import JSONFoundation
import SwiftTesting
import Testing
@testable import SearchFilesTool

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

    try toolUse.receive(output: .string(testOutput))
    let result = try await toolUse.output.results.map(\.path)
    #expect(result == [
      "/me/cmd/app/modules/serviceInterfaces/LocalServerServiceInterface/Sources/sendMessageSchema.generated.swift",
      "/me/cmd/app/modules/services/ChatHistoryService/Sources/Serialization.swift",
      "/me/cmd/app/modules/foundations/JSONFoundation/Sources/JSON.swift",
      "/me/cmd/app/modules/foundations/LLMFoundation/Sources/LLMProvider.swift",
      "/me/cmd/app/modules/services/LLMService/Sources/JSON+partialParsing.swift",
      "/me/cmd/app/modules/services/ChatHistoryService/Sources/AttachmentSerializer.swift",
      "/me/cmd/app/modules/serviceInterfaces/LocalServerServiceInterface/Tests/ErrorParsingTests.swift",
      "/me/cmd/app/modules/foundations/ToolFoundation/Sources/Encoding.swift",
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

    try toolUse.receive(output: .string(otherTestOutput))
    let results = try await toolUse.output.results

    // Validate we have the expected number of file results (5 unique files with matches)
    #expect(results.count == 2)

    // Validate first file result
    let firstResult = results[0]
    #expect(firstResult.path == "/me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift")
    #expect(firstResult.searchResults.count == 1)
    #expect(firstResult.searchResults[0].line == 154)
    #expect(firstResult.searchResults[0].text == "      setResult: { _ in },")
    #expect(firstResult.searchResults[0].isMatch == true)

    // Validate second file result - ToolUseViewModel.swift has multiple matches
    let secondResult = results[1]
    #expect(secondResult.path == "/me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift")
    #expect(secondResult.searchResults.count == 2)

    // Check the matched lines in ToolUseViewModel.swift
    #expect(secondResult.searchResults[0].line == 32)
    #expect(secondResult.searchResults[0].text == "    setResult: @escaping (EditFilesTool.Use.FormattedOutput) -> Void,")
    #expect(secondResult.searchResults[0].isMatch == true)

    #expect(secondResult.searchResults[1].line == 39)
    #expect(secondResult.searchResults[1].text == "    self.setResult = setResult")
    #expect(secondResult.searchResults[1].isMatch == true)
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

  private let testOutput = """
    Found 8 files
    /me/cmd/app/modules/serviceInterfaces/LocalServerServiceInterface/Sources/sendMessageSchema.generated.swift
    /me/cmd/app/modules/services/ChatHistoryService/Sources/Serialization.swift
    /me/cmd/app/modules/foundations/JSONFoundation/Sources/JSON.swift
    /me/cmd/app/modules/foundations/LLMFoundation/Sources/LLMProvider.swift
    /me/cmd/app/modules/services/LLMService/Sources/JSON+partialParsing.swift
    /me/cmd/app/modules/services/ChatHistoryService/Sources/AttachmentSerializer.swift
    /me/cmd/app/modules/serviceInterfaces/LocalServerServiceInterface/Tests/ErrorParsingTests.swift
    /me/cmd/app/modules/foundations/ToolFoundation/Sources/Encoding.swift
    """

  private let otherTestOutput = """
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift-152-      input: mappedInput,
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift-153-      isInputComplete: true,
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift:154:      setResult: { _ in },
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift-155-      context: context)
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ClaudeCodeWriteTool.swift-156-
    --
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-30-    input: [EditFilesTool.Use.FileChange],
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-31-    isInputComplete: Bool,
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift:32:    setResult: @escaping (EditFilesTool.Use.FormattedOutput) -> Void,
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-33-    toolUseResult: EditFilesTool.Use.FormattedOutput = .init(fileChanges: []),
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-34-    context: ToolExecutionContext)
    --
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-37-    self.input = input
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-38-    self.isInputComplete = isInputComplete
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift:39:    self.setResult = setResult
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-40-    self.toolUseResult = toolUseResult
    /me/cmd/app/modules/plugins/tools/EditFilesTool/Sources/ToolUseViewModel.swift-41-    self.context = context
    """
}
