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
public final class UnknownTool: NonStreamableTool {
  public init(name: String) {
    self.name = name
  }

  @ThreadSafe
  public final class Use: NonStreamableToolUse, UpdatableToolUse, @unchecked Sendable {

    public init(
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

    public typealias InternalState = JSON.Value

    public typealias Input = JSON.Value

    public typealias Output = JSON.Value

    public let internalState: JSONFoundation.JSON.Value?

    public let context: ToolExecutionContext

    @MainActor public lazy var viewModel = DefaultToolUseViewModel(toolName: callingTool.name, status: status, input: input)

    public let callingTool: UnknownTool
    public let toolUseId: String
    public let input: Input

    public let status: Status

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public var isReadonly: Bool {
      callingTool.isReadonly
    }

    public func startExecuting() {
      // Not supported
    }

    public func cancel() {
      // Not supported
    }

    /// The raw data that represented the missing tool use when serialized.
    let rawData: JSON.Value

  }

  public let name: String

  public var description: String {
    "Unknown tool \(name)"
  }

  public var inputSchema: JSON {
    .object([:])
  }

  public var displayName: String {
    name
  }

  public var shortDescription: String {
    description
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    false
  }

  var isReadonly: Bool {
    false
  }

}

extension UnknownTool.Use {
  public convenience init(from decoder: Decoder) throws {
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

  public func encode(to encoder: Encoder) throws {
    try rawData.encode(to: encoder)
  }
}
