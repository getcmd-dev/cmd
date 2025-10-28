// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      let input1 = ClaudeCodeTodoWriteTool.Use.Input(todos: [
        ClaudeCodeTodoWriteTool.Use.TodoItem(
          content: "Implement user authentication system",
          status: "in_progress",
          id: "1"),
        ClaudeCodeTodoWriteTool.Use.TodoItem(
          content: "Add API endpoints for data fetching",
          status: "pending",
          id: "2"),
      ])
      TodoWriteToolUseView(toolUse: TodoWriteToolUseViewModel(
        status: .Just(.running(input: input1)),
        input: input1))

      let input2 = ClaudeCodeTodoWriteTool.Use.Input(todos: [
        ClaudeCodeTodoWriteTool.Use.TodoItem(
          content: "Implement user authentication system",
          status: "completed",
          id: "1"),
        ClaudeCodeTodoWriteTool.Use.TodoItem(
          content: "Add API endpoints for data fetching",
          status: "in_progress",
          id: "2"),
        ClaudeCodeTodoWriteTool.Use.TodoItem(
          content: "Write unit tests for core functionality",
          status: "pending",
          id: "3"),
        ClaudeCodeTodoWriteTool.Use.TodoItem(
          content: "Update documentation with new features",
          status: "pending",
          id: "4"),
      ])
      TodoWriteToolUseView(toolUse: TodoWriteToolUseViewModel(
        status: .Just(.completed(input: input2, result: .success(.init(
          message: "Todo list updated successfully")))),
        input: input2))

      let input3 = ClaudeCodeTodoWriteTool.Use.Input(todos: Array(1...15).map { i in
        ClaudeCodeTodoWriteTool.Use.TodoItem(
          content: "Task \(i): Lorem ipsum dolor sit amet, consectetur adipiscing elit",
          status: i <= 5 ? "completed" : i <= 8 ? "in_progress" : "pending",
          id: "\(i)")
      })
      TodoWriteToolUseView(toolUse: TodoWriteToolUseViewModel(
        status: .Just(.completed(input: input3, result: .success(.init(
          message: "Todo list updated successfully with 15 items")))),
        input: input3))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
