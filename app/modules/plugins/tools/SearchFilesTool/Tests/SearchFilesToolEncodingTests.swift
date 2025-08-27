// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftTesting
import Testing
import ToolFoundation
@testable import SearchFilesTool

// MARK: - SearchFilesToolEncodingTests

struct SearchFilesToolEncodingTests {

  // MARK: - Tool Use Encoding/Decoding Tests

  @Test("Tool Use encoding/decoding - basic search")
  func test_toolUseEncodingDecodingBasic() throws {
    let tool = SearchFilesTool()
    let input = SearchFilesTool.Use.Input(
      directoryPath: "/project",
      regex: "FIXME",
      filePattern: nil)
    let use = tool.use(toolUseId: "search-123", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "search_files",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "directoryPath": "/project",
          "regex": "FIXME"
        },
        "internalState": null,
        "isInputComplete": true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "search-123"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - with file pattern")
  func test_toolUseEncodingDecodingWithPattern() throws {
    let tool = SearchFilesTool()
    let input = SearchFilesTool.Use.Input(
      directoryPath: "/codebase/src",
      regex: "class\\s+\\w+Test",
      filePattern: "*.swift")
    let use = tool.use(toolUseId: "search-pattern-456", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "search_files",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "directoryPath": "/codebase/src",
          "filePattern": "*.swift",
          "regex": "class\\\\s+\\\\w+Test"
        },
        "internalState": null,
        "isInputComplete": true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "search-pattern-456"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - complex regex")
  func test_toolUseEncodingDecodingComplexRegex() throws {
    let tool = SearchFilesTool()
    let input = SearchFilesTool.Use.Input(
      directoryPath: "/workspace/backend",
      regex: "api\\..*\\(",
      filePattern: "*.{py,js}")
    let use = tool.use(toolUseId: "search-structure-789", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "search_files",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "directoryPath": "/workspace/backend",
          "filePattern": "*.{py,js}",
          "regex": "api\\\\..*\\\\("
        },
        "internalState": null,
        "isInputComplete": true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "search-structure-789"
      }
      """)
  }
}

private let toolExecutionContext = ToolExecutionContext()

private func testDecodingEncodingWithTool(
  of value: some Codable,
  tool: any Tool,
  _ json: String)
  throws
{
  // Create decoder with tool plugin
  let toolsPlugin = ToolsPlugin()
  toolsPlugin.plugIn(tool: tool)
  let decoder = JSONDecoder()
  decoder.userInfo.set(toolPlugin: toolsPlugin)

  // Create encoder
  let encoder = JSONEncoder()

  // Use the test function with proper decoder/encoder
  try testDecodingEncoding(of: value, json, decoder: decoder, encoder: encoder)
}
