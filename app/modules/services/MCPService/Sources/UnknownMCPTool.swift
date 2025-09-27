// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFoundation
import Foundation
import JSONFoundation
import MCP
import ThreadSafe
import ToolFoundation

/// When an MCP tool was used in the past and is no longer available, this type can be used to deserialize and represent
/// the past tool use.
public final class UnknownMCPTool: NonStreamableTool {
  public init(name: String) {
    self.name = name
  }

  @ThreadSafe
  public final class Use: NonStreamableToolUse, UpdatableToolUse {

    public init(
      callingTool: UnknownMCPTool,
      toolUseId: String,
      input: Input,
      context: ToolFoundation.ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.input = input
      self.context = context

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject

    public typealias Input = MCPToolInput

    public typealias Output = MCPToolOutput

    public let context: ToolFoundation.ToolExecutionContext

    public let callingTool: UnknownMCPTool
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

  }

  public let name: String

  public var description: String {
    "MCP tool \(name)"
  }

  public var inputSchema: JSON {
    .object([:])
  }

  public var displayName: String {
    "\(name) (MCP)"
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
