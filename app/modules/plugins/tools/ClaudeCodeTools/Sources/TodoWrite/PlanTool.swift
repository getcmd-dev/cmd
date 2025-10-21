// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatServiceInterface
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation
import ToolTypesFoundation

// MARK: - PlanTool

public final class PlanTool: Tool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse,
    @unchecked Sendable
  {
    public init(
      callingTool: PlanTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState: InternalState? = nil,
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

      @Dependency(\.chatContextRegistry) var chatContextRegistry
      if let internalState {
        self.internalState = internalState
      } else {
        do {
          if
            let preExistingTodos: [ToolsSchema.TodoWriteToolInput_TodoItem] = try chatContextRegistry
              .context(for: context.threadId)
              .pluginState(for: Self.chatPluginName)
          {
            self.internalState = .init(preExistingTodos: preExistingTodos)
          } else {
            self.internalState = .init(preExistingTodos: [])
          }
        } catch {
          self.internalState = .init(preExistingTodos: [])
        }
      }
    }

    public typealias Input = ClaudeCodeTodoWriteTool.Use.Input
    public typealias Output = ClaudeCodeTodoWriteTool.Use.Output

    public typealias InternalState = PreExistingTodos
    public struct PreExistingTodos: Codable, Sendable {
      let preExistingTodos: [ToolsSchema.TodoWriteToolInput_TodoItem]
    }

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let internalState: InternalState?

    public let isReadonly = true

    public let callingTool: PlanTool
    public let toolUseId: String
    public let input: Input

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)
    }

    public func receive(output: JSONFoundation.JSON.Value) throws {
      let output = try JSONDecoder().decode(Output.self, from: JSONEncoder().encode(output))
      updateStatus.complete(with: .success(output))

      do {
        @Dependency(\.chatContextRegistry) var chatContextRegistry
        try chatContextRegistry.context(for: context.threadId).set(pluginState: input.todos, for: Self.chatPluginName)
      } catch { }
    }

    public func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
    }

    private static let chatPluginName = "current_todos"

  }

  public let canBeExecuted = false

  public let id = "todo_write"
  public let name = "todo_write"

  public let description = """
    Use this tool to create and manage a structured task list for your current coding session. This helps you track progress, organize complex tasks, and demonstrate thoroughness to the user.
    """

  public var referenceId: String { id }

  public var displayName: String {
    "Plan"
  }

  public var shortDescription: String {
    "Create and manage structured task lists for coding sessions."
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
            ]),
            "required": .array([
              .string("content"),
              .string("status"),
            ]),
          ]),
          "description": .string("The updated todo list"),
        ]),
      ]),
      "required": .array([.string("todos")]),
    ])
  }

}

// MARK: - PlanTool.Use + DisplayableToolUse

extension PlanTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(TodoWriteToolUseViewModel(
      status: status,
      input: input,
      preExistingTodos: internalState?.preExistingTodos.map { .init(content: $0.content, status: $0.status, id: $0.content) }))
  }
}
