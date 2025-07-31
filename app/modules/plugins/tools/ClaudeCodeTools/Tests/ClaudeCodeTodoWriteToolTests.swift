// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import JSONFoundation
import SwiftTesting
import Testing
@testable import ClaudeCodeTools

struct ClaudeCodeTodoWriteToolTests {

  @Test
  func handlesSuccessfulTodoWriteOutput() async throws {
    let todoItems = [
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Implement authentication",
        status: "pending",
        priority: "high",
        id: "1"),
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Add unit tests",
        status: "in_progress",
        priority: "medium",
        id: "2"),
    ]

    let toolUse = ClaudeCodeTodoWriteTool().use(
      toolUseId: "123",
      input: .init(todos: todoItems),
      isInputComplete: true,
      context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate successful output from Claude Code
    let output = "Todos have been modified successfully"

    try toolUse.receive(output: output)
    let result = try await toolUse.output

    #expect(result.success == true)
    #expect(result.message == "Todo list updated successfully")
  }

  @Test
  func handlesFailedTodoWriteOutput() async throws {
    let todoItems = [
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Invalid task",
        status: "invalid_status",
        priority: "high",
        id: "1"),
    ]

    let toolUse = ClaudeCodeTodoWriteTool().use(
      toolUseId: "456",
      input: .init(todos: todoItems),
      isInputComplete: true,
      context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate error output from Claude Code
    let errorMessage = "Error: Invalid todo status provided"

    try toolUse.receive(output: errorMessage)
    let result = try await toolUse.output

    #expect(result.success == false)
    #expect(result.message == errorMessage)
  }

  @Test
  func handlesEmptyTodoList() async throws {
    let toolUse = ClaudeCodeTodoWriteTool().use(
      toolUseId: "789",
      input: .init(todos: []),
      isInputComplete: true,
      context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate successful output for empty list
    let output = "Todos have been modified successfully"

    try toolUse.receive(output: output)
    let result = try await toolUse.output

    #expect(result.success == true)
    #expect(result.message == "Todo list updated successfully")
  }

  @Test
  func handlesLargeTodoList() async throws {
    let todoItems = (1...50).map { i in
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Task \(i): Long description of what needs to be done",
        status: i <= 10 ? "completed" : i <= 20 ? "in_progress" : "pending",
        priority: i <= 15 ? "high" : i <= 35 ? "medium" : "low",
        id: "\(i)")
    }

    let toolUse = ClaudeCodeTodoWriteTool().use(
      toolUseId: "large",
      input: .init(todos: todoItems),
      isInputComplete: true,
      context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate successful output
    let output = "Todos have been modified successfully"

    try toolUse.receive(output: output)
    let result = try await toolUse.output

    #expect(result.success == true)
    #expect(result.message == "Todo list updated successfully")
  }

  @Test
  func correctlyParsesAllTodoStatuses() async throws {
    let todoItems = [
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Pending task",
        status: "pending",
        priority: "high",
        id: "1"),
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "In progress task",
        status: "in_progress",
        priority: "medium",
        id: "2"),
      ClaudeCodeTodoWriteTool.Use.TodoItem(
        content: "Completed task",
        status: "completed",
        priority: "low",
        id: "3"),
    ]

    let toolUse = ClaudeCodeTodoWriteTool().use(
      toolUseId: "statuses",
      input: .init(todos: todoItems),
      isInputComplete: true,
      context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))

    #expect(toolUse.input.todos.count == 3)
    #expect(toolUse.input.todos[0].status == "pending")
    #expect(toolUse.input.todos[1].status == "in_progress")
    #expect(toolUse.input.todos[2].status == "completed")
    #expect(toolUse.input.todos[0].priority == "high")
    #expect(toolUse.input.todos[1].priority == "medium")
    #expect(toolUse.input.todos[2].priority == "low")
  }

  @Test
  func isNotReadOnly() {
    let tool = ClaudeCodeTodoWriteTool()
    let toolUse = tool.use(
      toolUseId: "readonly",
      input: .init(todos: []),
      isInputComplete: true,
      context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))

    #expect(toolUse.isReadonly == false)
  }

  @Test
  func isAvailableInAllChatModes() {
    let tool = ClaudeCodeTodoWriteTool()

    #expect(tool.isAvailable(in: .ask) == true)
    #expect(tool.isAvailable(in: .agent) == true)
  }

  @Test
  func hasCorrectToolName() {
    let tool = ClaudeCodeTodoWriteTool()
    #expect(tool.name == "claude_code_TodoWrite")
  }

  @Test
  func hasCorrectDisplayNames() {
    let tool = ClaudeCodeTodoWriteTool()
    #expect(tool.displayName == "TodoWrite (Claude Code)")
    #expect(tool.shortDescription == "Claude Code tool to create and manage structured task lists for coding sessions.")
  }
}
