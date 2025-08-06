// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import Foundation
import JSONFoundation
import ToolFoundation

// MARK: - ClaudeCodeTodoWriteTool

public final class ClaudeCodeTodoWriteTool: ExternalTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    public init(
      callingTool: ClaudeCodeTodoWriteTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = input

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject
    public struct TodoItem: Codable, Sendable {
      public let content: String
      public let status: String
      public let priority: String
      public let id: String
    }

    public struct Input: Codable, Sendable {
      public let todos: [TodoItem]
    }

    public struct Output: Codable, Sendable {
      public let success: Bool
      public let message: String
    }

    public let isReadonly = true

    public let callingTool: ClaudeCodeTodoWriteTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func receive(output: String) throws {
      // Parse the todo write output from Claude Code
      let success = output.contains("successfully")
      let message = success ? "Todo list updated successfully" : output

      updateStatus.complete(with: .success(.init(success: success, message: message)))
    }

  }

  public let name = "claude_code_TodoWrite"

  public let description = """
    Use this tool to create and manage a structured task list for your current coding session. This helps you track progress, organize complex tasks, and demonstrate thoroughness to the user.
    It also helps the user understand the progress of the task and overall progress of their requests.

    ## When to Use This Tool
    Use this tool proactively in these scenarios:

    1. Complex multi-step tasks - When a task requires 3 or more distinct steps or actions
    2. Non-trivial and complex tasks - Tasks that require careful planning or multiple operations
    3. User explicitly requests todo list - When the user directly asks you to use the todo list
    4. User provides multiple tasks - When users provide a list of things to be done (numbered or comma-separated)
    5. After receiving new instructions - Immediately capture user requirements as todos
    6. When you start working on a task - Mark it as in_progress BEFORE beginning work. Ideally you should only have one todo as in_progress at a time
    7. After completing a task - Mark it as completed and add any new follow-up tasks discovered during implementation

    ## Task States and Management

    1. **Task States**: Use these states to track progress:
       - pending: Task not yet started
       - in_progress: Currently working on (limit to ONE task at a time)
       - completed: Task finished successfully

    2. **Task Management**:
       - Update task status in real-time as you work
       - Mark tasks complete IMMEDIATELY after finishing (don't batch completions)
       - Only have ONE task in_progress at any time
       - Complete current tasks before starting new ones
       - Remove tasks that are no longer relevant from the list entirely

    3. **Task Completion Requirements**:
       - ONLY mark a task as completed when you have FULLY accomplished it
       - If you encounter errors, blockers, or cannot finish, keep the task as in_progress
       - When blocked, create a new task describing what needs to be resolved
       - Never mark a task as completed if:
         - Tests are failing
         - Implementation is partial
         - You encountered unresolved errors
         - You couldn't find necessary files or dependencies

    4. **Task Breakdown**:
       - Create specific, actionable items
       - Break complex tasks into smaller, manageable steps
       - Use clear, descriptive task names

    When in doubt, use this tool. Being proactive with task management demonstrates attentiveness and ensures you complete all requirements successfully.
    """

  public var displayName: String {
    "TodoWrite (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to create and manage structured task lists for coding sessions."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "todos": .object([
          "type": .string("array"),
          "items": .object([
            "type": .string("object"),
            "properties": .object([
              "content": .object([
                "type": .string("string"),
                "minLength": .number(1),
              ]),
              "status": .object([
                "type": .string("string"),
                "enum": .array([
                  .string("pending"),
                  .string("in_progress"),
                  .string("completed"),
                ]),
              ]),
              "priority": .object([
                "type": .string("string"),
                "enum": .array([
                  .string("high"),
                  .string("medium"),
                  .string("low"),
                ]),
              ]),
              "id": .object([
                "type": .string("string"),
              ]),
            ]),
            "required": .array([
              .string("content"),
              .string("status"),
              .string("priority"),
              .string("id"),
            ]),
            "additionalProperties": .bool(false),
          ]),
          "description": .string("The updated todo list"),
        ]),
      ]),
      "required": .array([.string("todos")]),
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

}

// MARK: - TodoWriteToolUseViewModel

@Observable
@MainActor
final class TodoWriteToolUseViewModel {

  init(status: ClaudeCodeTodoWriteTool.Use.Status, input: ClaudeCodeTodoWriteTool.Use.Input) {
    self.status = status.value
    self.input = input
    Task { [weak self] in
      for await status in status {
        self?.status = status
      }
    }
  }

  let input: ClaudeCodeTodoWriteTool.Use.Input
  var status: ToolUseExecutionStatus<ClaudeCodeTodoWriteTool.Use.Output>
}
