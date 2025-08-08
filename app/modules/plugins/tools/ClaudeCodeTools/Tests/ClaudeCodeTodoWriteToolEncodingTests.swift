// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftTesting
import Testing
import ToolFoundation
@testable import ClaudeCodeTools

// MARK: - ClaudeCodeTodoWriteToolEncodingTests

struct ClaudeCodeTodoWriteToolEncodingTests {

  // MARK: - Tool Use Encoding/Decoding Tests

  @Test("Tool Use encoding/decoding - single todo")
  func test_toolUseEncodingDecodingSingleTodo() throws {
    let tool = ClaudeCodeTodoWriteTool()
    let todoItems = [
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Implement authentication",
        status: "pending",
        id: "1"),
    ]
    let input = ClaudeCodeTodoWriteTool.Use.Input(todos: todoItems)
    let use = tool.use(toolUseId: "todo-123", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "claude_code_TodoWrite",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "todos": [
            {
              "content": "Implement authentication",
              "status": "pending",
              "id": "1"
            }
          ]
        },
        "internalState": {
          "preExistingTodos" : []
        },
        "isInputComplete" : true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "todo-123"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - multiple todos")
  func test_toolUseEncodingDecodingMultipleTodos() throws {
    let tool = ClaudeCodeTodoWriteTool()
    let todoItems = [
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Implement authentication",
        status: "completed",
        id: "1"),
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Add API endpoints",
        status: "in_progress",
        id: "2"),
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Write documentation",
        status: "pending",
        id: "3"),
    ]
    let input = ClaudeCodeTodoWriteTool.Use.Input(todos: todoItems)
    let use = tool.use(toolUseId: "todo-456", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "claude_code_TodoWrite",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "todos": [
            {
              "content": "Implement authentication",
              "status": "completed",
              "id": "1"
            },
            {
              "content": "Add API endpoints",
              "status": "in_progress",
              "id": "2"
            },
            {
              "content": "Write documentation",
              "status": "pending",
              "id": "3"
            }
          ]
        },
        "internalState": {
          "preExistingTodos" : []
        },
        "isInputComplete" : true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "todo-456"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - empty todo list")
  func test_toolUseEncodingDecodingEmptyTodoList() throws {
    let tool = ClaudeCodeTodoWriteTool()
    let input = ClaudeCodeTodoWriteTool.Use.Input(todos: [])
    let use = tool.use(toolUseId: "todo-empty", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "claude_code_TodoWrite",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "todos": []
        },
        "internalState": {
          "preExistingTodos" : []
        },
        "isInputComplete" : true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "todo-empty"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - long content")
  func test_toolUseEncodingDecodingLongContent() throws {
    let tool = ClaudeCodeTodoWriteTool()
    let longContent = "This is a very long todo item content that contains detailed information about what needs to be implemented, including specific requirements, edge cases to consider, and implementation details that should be addressed during development."
    let todoItems = [
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: longContent,
        status: "pending",
        id: "long-1"),
    ]
    let input = ClaudeCodeTodoWriteTool.Use.Input(todos: todoItems)
    let use = tool.use(toolUseId: "todo-long", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "claude_code_TodoWrite",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "todos": [
            {
              "content": "\(longContent)",
              "status": "pending",
              "id": "long-1"
            }
          ]
        },
        "internalState": {
          "preExistingTodos" : []
        },
        "isInputComplete" : true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "todo-long"
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
