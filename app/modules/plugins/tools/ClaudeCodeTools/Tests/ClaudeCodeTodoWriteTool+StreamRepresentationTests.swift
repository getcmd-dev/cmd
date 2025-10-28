// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Testing
@testable import ClaudeCodeTools

extension ClaudeCodeTodoWriteToolTests {

  @MainActor
  @Test("streamRepresentation returns nil when status is not completed")
  func test_streamRepresentationNilWhenNotCompleted() {
    let input = ClaudeCodeTodoWriteTool.Use.Input(todos: [
      .init(content: "Test task", status: "pending", id: "1"),
    ])
    let (status, _) = ClaudeCodeTodoWriteTool.Use.Status.makeStream(initial: .running(input: input))

    let viewModel = TodoWriteToolUseViewModel(
      status: status,
      input: input)

    #expect(viewModel.streamRepresentation == nil)
  }

  @MainActor
  @Test("streamRepresentation shows successful todo update with changed items")
  func test_streamRepresentationSuccessWithChangedTodos() {
    // given
    let input = ClaudeCodeTodoWriteTool.Use.Input(todos: [
      .init(content: "Implement feature A", status: "completed", id: "1"),
      .init(content: "Add unit tests", status: "in_progress", id: "2"),
      .init(content: "Write documentation", status: "pending", id: "3"),
    ])
    let output = ClaudeCodeTodoWriteTool.Use.Output(
      message: "Todo list updated successfully")
    let (status, _) = ClaudeCodeTodoWriteTool.Use.Status.makeStream(initial: .completed(input: input, result: .success(output)))

    let viewModel = TodoWriteToolUseViewModel(
      status: status,
      input: input)

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Update Todos
        ⎿ ☒ Implement feature A
        ⎿ → Add unit tests
        ⎿ ☐ Write documentation


      """)
  }

  @MainActor
  @Test("streamRepresentation shows failure with error")
  func test_streamRepresentationFailure() {
    // given
    let input = ClaudeCodeTodoWriteTool.Use.Input(todos: [
      .init(content: "Invalid task", status: "invalid", id: "1"),
    ])
    let error = AppError("Invalid todo status")
    let (status, _) = ClaudeCodeTodoWriteTool.Use.Status.makeStream(initial: .completed(input: input, result: .failure(error)))

    let viewModel = TodoWriteToolUseViewModel(
      status: status,
      input: input)

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ TodoWrite(1 items)
        ⎿ Failed: Invalid todo status


      """)
  }
}
