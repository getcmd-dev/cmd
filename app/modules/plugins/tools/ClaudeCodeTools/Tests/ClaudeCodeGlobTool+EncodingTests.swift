// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftTesting
import Testing
import ToolFoundation
@testable import ClaudeCodeTools

// MARK: - ClaudeCodeGlobToolEncodingTests

struct ClaudeCodeGlobToolEncodingTests {

  // MARK: - Tool Use Encoding/Decoding Tests

  @Test("Tool Use encoding/decoding - pattern only")
  func test_toolUseEncodingDecodingPatternOnly() throws {
    let tool = ClaudeCodeGlobTool()
    let input = ClaudeCodeGlobTool.Use.Input(
      pattern: "**/*.swift",
      path: nil)
    let use = tool.use(toolUseId: "glob-123", input: input, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "claude_code_glob",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "type": "glob_input",
          "pattern": "**/*.swift"
        },
        "internalState": null,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "glob-123"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - with path")
  func test_toolUseEncodingDecodingWithPath() throws {
    let tool = ClaudeCodeGlobTool()
    let input = ClaudeCodeGlobTool.Use.Input(
      pattern: "src/**/*.ts",
      path: "/Users/user/project")
    let use = tool.use(toolUseId: "glob-456", input: input, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "claude_code_glob",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "type": "glob_input",
          "pattern": "src/**/*.ts",
          "path": "/Users/user/project"
        },
        "internalState": null,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "glob-456"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - complex pattern")
  func test_toolUseEncodingDecodingComplexPattern() throws {
    let tool = ClaudeCodeGlobTool()
    let input = ClaudeCodeGlobTool.Use.Input(
      pattern: "**/*.{js,ts,jsx,tsx}",
      path: "/project/frontend")
    let use = tool.use(toolUseId: "glob-789", input: input, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "claude_code_glob",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "type": "glob_input",
          "pattern": "**/*.{js,ts,jsx,tsx}",
          "path": "/project/frontend"
        },
        "internalState": null,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "glob-789"
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
