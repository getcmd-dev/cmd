// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftTesting
import Testing
import ToolFoundation
@testable import ExecuteCommandTool

// MARK: - ExecuteCommandToolEncodingTests

struct ExecuteCommandToolEncodingTests {

  // MARK: - Tool Use Encoding/Decoding Tests

  @Test("Tool Use encoding/decoding - basic command")
  func test_toolUseEncodingDecodingBasic() throws {
    let tool = ExecuteCommandTool()
    let input = ExecuteCommandTool.Use.Input(
      command: "pwd",
      cwd: nil,
      canModifySourceFiles: false,
      canModifyDerivedFiles: false)
    let use = tool.use(toolUseId: "exec-123", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "execute_command",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "canModifyDerivedFiles": false,
          "canModifySourceFiles": false,
          "command": "pwd"
        },
        "internalState": null,
        "isInputComplete": true,
        "status": {
          "status": "pendingApproval"
        },
        "toolUseId": "exec-123"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - with working directory")
  func test_toolUseEncodingDecodingWithCwd() throws {
    let tool = ExecuteCommandTool()
    let input = ExecuteCommandTool.Use.Input(
      command: "git status",
      cwd: "/path/to/project",
      canModifySourceFiles: false,
      canModifyDerivedFiles: true)
    let use = tool.use(toolUseId: "exec-git-456", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "execute_command",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "canModifyDerivedFiles": true,
          "canModifySourceFiles": false,
          "command": "git status",
          "cwd": "/path/to/project"
        },
        "internalState": null,
        "isInputComplete": true,
        "status": {
          "status": "pendingApproval"
        },
        "toolUseId": "exec-git-456"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - with permissions")
  func test_toolUseEncodingDecodingWithPermissions() throws {
    let tool = ExecuteCommandTool()
    let input = ExecuteCommandTool.Use.Input(
      command: "swift build",
      cwd: "/source",
      canModifySourceFiles: true,
      canModifyDerivedFiles: true)
    let use = tool.use(toolUseId: "exec-build-789", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "execute_command",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "canModifyDerivedFiles": true,
          "canModifySourceFiles": true,
          "command": "swift build",
          "cwd": "/source"
        },
        "internalState": null,
        "isInputComplete": true,
        "status": {
          "status": "pendingApproval"
        },
        "toolUseId": "exec-build-789"
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
