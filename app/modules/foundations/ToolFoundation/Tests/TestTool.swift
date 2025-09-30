// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import JSONFoundation
import ThreadSafe
import ToolFoundation

struct TestTool: NonStreamableTool {
  init(name: String = "TestTool") {
    self.name = name
  }

  // MARK: - TestToolUse

  @ThreadSafe
  struct Use: NonStreamableToolUse, Codable {

    init(
      callingTool: TestTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: EmptyObject? = nil,
      initialStatus: Status.Element?)
    {
      self.toolUseId = toolUseId
      self.callingTool = callingTool
      self.context = context
      self.input = input

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public let status: Status

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    typealias InternalState = EmptyObject

    struct Input: Codable, Sendable {
      let preparedOutput: Result<Output, Error>

      typealias Output = JSON.Value
    }

    typealias Output = Input.Output

    typealias Status = CurrentValueStream<ToolUseExecutionStatus<Output>>

    let context: ToolExecutionContext
    let callingTool: TestTool
    let toolUseId: String
    let isReadonly = false
    let input: Input

    func startExecuting() {
      updateStatus.complete(with: input.preparedOutput)
    }

    func reject(reason _: String?) { }

    func cancel() { }

    func waitForApproval() { }

  }

  let name: String

  var displayName: String { name }
  var shortDescription: String { "tool for testing" }

  var description: String { "tool for testing" }
  var inputSchema: JSON { .object([:]) }

  func isAvailable(in _: ChatFoundation.ChatMode) -> Bool {
    true
  }

}
