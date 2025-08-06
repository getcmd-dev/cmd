// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import JSONFoundation
import ToolFoundation

// MARK: - FailedToolUse

struct FailedToolUse: NonStreamableToolUse {
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
  }

  init(toolUseId: String, toolName: String, errorDescription: String, context: ToolFoundation.ToolExecutionContext) {
    let callingTool = FailedTool(name: toolName)
    self.init(
      callingTool: callingTool,
      toolUseId: toolUseId,
      input: Input(errorDescription: errorDescription),
      context: context,
      initialStatus: nil)
  }

  public typealias InternalState = EmptyObject

  public let context: ToolFoundation.ToolExecutionContext

  public let isReadonly = true

  struct Input: Codable {
    let errorDescription: String
  }

  typealias Output = EmptyObject

  let callingTool: FailedTool
  let toolUseId: String
  let input: Input

  var errorDescription: String { input.errorDescription }

  var status: CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<EmptyObject>> {
    .Just(.completed(.failure(AppError(errorDescription))))
  }

  func startExecuting() { }

  func reject(reason _: String?) { }

  func cancel() { }
}

// MARK: - FailedTool

struct FailedTool: NonStreamableTool {
  init(name: String) {
    self.name = name
  }

  typealias Use = FailedToolUse

  let name: String

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
