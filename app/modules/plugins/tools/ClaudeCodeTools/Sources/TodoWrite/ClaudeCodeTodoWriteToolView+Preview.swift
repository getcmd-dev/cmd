// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      TodoWriteToolUseView(toolUse: TodoWriteToolUseViewModel(
        status: .Just(.running),
        input: .init(todos: [
          ClaudeCodeTodoWriteTool.Use.TodoItem(
            content: "Implement user authentication system",
            status: "in_progress",
            id: "1"),
          ClaudeCodeTodoWriteTool.Use.TodoItem(
            content: "Add API endpoints for data fetching",
            status: "pending",
            id: "2"),
        ])))

      TodoWriteToolUseView(toolUse: TodoWriteToolUseViewModel(
        status: .Just(.completed(.success(.init(
          success: true,
          message: "Todo list updated successfully")))),
        input: .init(todos: [
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
        ])))

      TodoWriteToolUseView(toolUse: TodoWriteToolUseViewModel(
        status: .Just(.completed(.success(.init(
          success: true,
          message: "Todo list updated successfully with 15 items")))),
        input: .init(todos: Array(1...15).map { i in
          ClaudeCodeTodoWriteTool.Use.TodoItem(
            content: "Task \(i): Lorem ipsum dolor sit amet, consectetur adipiscing elit",
            status: i <= 5 ? "completed" : i <= 8 ? "in_progress" : "pending",
            id: "\(i)")
        })))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
