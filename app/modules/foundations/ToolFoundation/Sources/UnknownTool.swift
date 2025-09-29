// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFoundation
import Foundation
import JSONFoundation
import ThreadSafe

// MARK: - UnknownTool

/// Represents a tool that was previously used but is no longer available in the current application state.
/// This type enables deserialization and representation of legacy tool usage data when the original tool type is unavailable.
final class UnknownTool: NonStreamableTool {
  init(name: String) {
    self.name = name
  }

  @ThreadSafe
  final class Use: NonStreamableToolUse, UpdatableToolUse {

    init(
      callingTool: UnknownTool,
      toolUseId: String,
      input: Input,
      context: ToolFoundation.ToolExecutionContext,
      internalState: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.input = input
      self.context = context

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.internalState = internalState
      self.updateStatus = updateStatus
      rawData = internalState ?? .object([:])
    }

    typealias InternalState = JSON.Value

    typealias Input = JSON.Value

    typealias Output = JSON.Value

    let internalState: JSONFoundation.JSON.Value?

    /// The raw data that represented the missing tool use when serialized.
    let rawData: JSON.Value

    let context: ToolExecutionContext

    let callingTool: UnknownTool
    let toolUseId: String
    let input: Input

    let status: Status

    let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    var isReadonly: Bool {
      callingTool.isReadonly
    }

    func startExecuting() {
      // Not supported
    }

    func cancel() {
      // Not supported
    }

  }

  let name: String

  var description: String {
    "Unknown tool \(name)"
  }

  var inputSchema: JSON {
    .object([:])
  }

  var displayName: String {
    name
  }

  var shortDescription: String {
    description
  }

  var isReadonly: Bool {
    false
  }

  func isAvailable(in _: ChatMode) -> Bool {
    false
  }

}

extension UnknownTool.Use {
  convenience init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: ToolUseCodingKeys.self)

    let callingTool = try container.decode(SomeTool.self, forKey: .callingTool)
    let toolUseId = try container.decode(String.self, forKey: .toolUseId)
    let input = try container.decode(Input.self, forKey: .input)
    let context = try container.decode(ToolExecutionContext.self, forKey: .context)
    let statusValue = try container.decode(ToolUseExecutionStatus<Output>.self, forKey: .status)
    let isInputComplete = try container.decode(Bool.self, forKey: .isInputComplete)

    let rawData = try JSON.Value(from: decoder)

    self.init(
      callingTool: callingTool,
      toolUseId: toolUseId,
      input: input,
      isInputComplete: isInputComplete,
      context: context,
      internalState: rawData,
      initialStatus: statusValue)
  }

  func encode(to encoder: Encoder) throws {
    try rawData.encode(to: encoder)
  }
}
