// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import LoggingServiceInterface
import SwiftUI
import ThreadSafe
import ToolFoundation
import ToolTypesFoundation

// MARK: - ACPTool

public final class ACPTool: Tool {

  init(id: String, referenceId: String, displayName: String) {
    self.id = id
    self.referenceId = referenceId
    self.displayName = displayName
  }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse,
    @unchecked Sendable
  {

    public init(
      callingTool: ACPTool,
      toolUseId: String,
      inputResult: Result<Input, ToolDecodingError>,
      context: ToolExecutionContext,
      internalState: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.internalState = internalState

      // Extract input or create fallback
      let input: Input
      switch inputResult {
      case .success(let value):
        input = value
      case .failure:
        // Fallback for failed decoding - use think as a safe default
        input = Input(kind: .think, title: "", rawInput: nil)
      }

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted(input: input))
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject
    public typealias Input = ToolsSchema.ACPToolInput
    public typealias Output = ToolsSchema.ACPToolOutput

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let callingTool: ACPTool
    public let toolUseId: String
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Input, Output>>.Continuation

    public let internalState: InternalState?

    /// ACP tools can be both readonly and non-readonly depending on the kind
    public var isReadonly: Bool {
      guard let input = status.value.input else { return false }
      switch input.kind {
      case .read, .search, .think, .fetch:
        return true
      case .edit, .delete, .move, .execute, .switchMode, .other:
        return false
      }
    }

    public func startExecuting() {
      guard let input = status.value.input else { return }
      // ACP tools are executed externally, so we just transition to running
      // The actual execution happens on the server side
      updateStatus.yield(.notStarted(input: input))
      updateStatus.yield(.running(input: input))
    }

    public func receive(output: JSONFoundation.JSON.Value) throws {
      guard let input = status.value.input else { return }
      let output = try JSONDecoder().decode(Output.self, from: JSONEncoder().encode(output))
      updateStatus.complete(with: .success(output), input: input)
    }

    public func cancel() {
      guard let input = status.value.input else { return }
      updateStatus.complete(with: .failure(CancellationError()), input: input)
    }

  }

  public static var allTools: [ACPTool] {
    ToolsSchema.ACPToolKind.allCases.map {
      ACPTool(id: "acp_\($0.rawValue)", referenceId: $0.referenceId, displayName: $0.name)
    }
  }

  public let id: String
  public let description = """
    ACP (Agent Client Protocol) tool represents external tool executions from ACP-based agents.
    This tool is used to display and track tool uses that are executed by external agents.
    """

  public let referenceId: String

  public let displayName: String

  public var name: String { id }

  public var shortDescription: String {
    "External tool execution via ACP"
  }

  public var inputSchema: JSON {
    .object([:])
  }

  /// ACP tools cannot be executed directly - they represent external executions
  public var canBeExecuted: Bool { false }

}

// MARK: - ACPTool.Use + DisplayableToolUse

extension ACPTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(ToolUseViewModel(
      status: status,
      input: input ?? Input(kind: .think, title: "", rawInput: nil),
      projectRoot: context.projectRoot))
  }
}

extension ToolsSchema.ACPToolKind {
  var referenceId: String {
    switch self {
    case .read:
      "read_file"
    case .edit:
      "edit_file"
    case .delete:
      "edit_file"
    case .move:
      "edit_file"
    case .search:
      "search"
    case .execute:
      "bash"
    case .think:
      "unknownTool"
    case .fetch:
      "web_fetch" // Maybe incorrect
    case .switchMode:
      "unknownTool"
    case .other:
      "unknownTool"
    }
  }

  var name: String {
    switch self {
    case .read:
      "Read"
    case .edit:
      "Edit"
    case .delete:
      "Delete"
    case .move:
      "Move"
    case .search:
      "Search"
    case .execute:
      "Bash"
    case .think:
      "Think"
    case .fetch:
      "Fetch"
    case .switchMode:
      "Switch Mode"
    case .other:
      "Other"
    }
  }
}
