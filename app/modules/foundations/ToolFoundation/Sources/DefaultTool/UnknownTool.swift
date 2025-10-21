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
public final class UnknownTool: Tool {
  public init(name: String, isExternalAgent: Bool) {
    self.name = name
    self.isExternalAgent = isExternalAgent
  }

  @ThreadSafe
  public final class Use: ToolUse, @unchecked Sendable {

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
      self.updateStatus = updateStatus
      self.internalState = internalState ?? .init(isExternalAgent: callingTool.isExternalAgent)
    }

    public struct InternalState: Codable, Sendable {
      /// When the tool is deserialized, the tool context is lost, and we only have the toolName left.
      /// So we need to persist any information about the tool of interest.
      let isExternalAgent: Bool
    }

    public typealias Input = JSON.Value

    public typealias Output = JSON.Value

    public private(set) var internalState: InternalState?

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
      if internalState?.isExternalAgent ?? callingTool.isExternalAgent {
        // The external agent will set the results
        updateStatus.yield(.notStarted)
        updateStatus.yield(.running)
      } else {
        updateStatus.complete(with: .failure(AppError("Missing tool \(toolName)")))
      }
    }

    public func cancel() {
      // Not supported
    }

  }

  public let name: String

  public var id: String { name }
  public var referenceId: String { id }

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

  let isExternalAgent: Bool

  var isReadonly: Bool {
    false
  }

}
