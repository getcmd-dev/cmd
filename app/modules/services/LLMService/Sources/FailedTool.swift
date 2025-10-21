// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import JSONFoundation
import ToolFoundation

// MARK: - FailedToolUse

struct FailedToolUse: ToolUse {
  init(
    callingTool: FailedTool,
    toolUseId: String,
    input: Input,
    context: ToolFoundation.ToolExecutionContext,
    internalState _: InternalState? = nil,
    initialStatus _: Status.Element?)
  {
    self.callingTool = callingTool
    self.input = input
    self.context = context
    self.toolUseId = toolUseId
    let (status, updateStatus) = Status.makeStream(initial: .completed(.failure(AppError(input.errorDescription))))
    updateStatus.finish()
    self.status = status
    self.updateStatus = updateStatus
  }

  init(toolUseId: String, toolName: String, errorDescription: String, context: ToolExecutionContext) {
    let callingTool = FailedTool(name: toolName)
    self.init(
      callingTool: callingTool,
      toolUseId: toolUseId,
      input: Input(errorDescription: errorDescription),
      context: context,
      initialStatus: nil)
  }

  public typealias InternalState = EmptyObject

  public let context: ToolExecutionContext

  public let isReadonly = true

  struct Input: Codable {
    let errorDescription: String
  }

  typealias Output = EmptyObject

  let updateStatus: AsyncStream<ToolUseExecutionStatus<EmptyObject>>.Continuation

  let callingTool: FailedTool
  let toolUseId: String
  let input: Input

  let status: CurrentValueStream<ToolUseExecutionStatus<EmptyObject>>

  var errorDescription: String { input.errorDescription }

  func startExecuting() { }

  func reject(reason _: String?) { }

  func cancel() { }

  func waitForApproval() { }
}

// MARK: - FailedTool

struct FailedTool: Tool {
  init(name: String) {
    self.name = name
  }

  typealias Use = FailedToolUse

  let name: String

  var id: String { name }
  var referenceId: String { id }

  var displayName: String {
    "Failed tool"
  }

  var shortDescription: String {
    "Placeholder for tools that failed to execute properly."
  }

  var description: String { "Failed tool" }
  var inputSchema: JSON { .object([:]) }

  func isAvailable(in _: ChatMode) -> Bool {
    true
  }
}
