// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
// Re-export ChatFoundation as the protocols defined here depend on types from this module.
@_exported import ChatFoundation
import Combine
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import LoggingServiceInterface
import SwiftUI

// MARK: - Tool

/// A tool that can be called by the assistant and execute tasks locally.
/// Each invocation of the tool is a 'tool use' that has its own input/output/state and possibly UI.
public protocol Tool: Sendable {
  associatedtype Use: ToolUse where Use.SomeTool == Self
  /// The name of the tool, used to identify it. It should only contain alphanumeric characters.
  var name: String { get }
  /// A description of what the tool does. The description of its input parameters is better suited for the `inputSchema` property.
  var description: String { get }
  /// The schema of the input parameters of the tool.
  var inputSchema: JSON { get }
  /// Whether the tool is available in the given chat mode.
  func isAvailable(in mode: ChatMode) -> Bool
  /// Whether this tool expect to receive the input as it is being streamed, or only once it is received entirely.
  var canInputBeStreamed: Bool { get }
  /// The tool display name
  var displayName: String { get }
  /// A short description of the tool (max 3 lines)
  var shortDescription: String { get }
}

extension Tool {
  public typealias Input = Use.Input
  public typealias Output = Use.Output

  /// Use the tool with the given input. This doesn't start the execution, which happens when `startExecuting` is called on the tool use.
  public func use(toolUseId: String, input: Use.Input, isInputComplete: Bool, context: ToolExecutionContext) -> Use {
    Use(
      callingTool: self,
      toolUseId: toolUseId,
      input: input,
      isInputComplete: isInputComplete,
      context: context,
      internalState: nil,
      initialStatus: nil)
  }

  public func use(toolUseId: String, input: Data, isInputComplete: Bool, context: ToolExecutionContext) throws -> Use {
    let decodedInput = try JSONDecoder().decode(Input.self, from: input)
    return use(toolUseId: toolUseId, input: decodedInput, isInputComplete: isInputComplete, context: context)
  }
}

// MARK: - ToolUse

/// A specific usage of a tool.
public protocol ToolUse: Sendable, Codable {
  associatedtype Input: Codable & Sendable
  associatedtype Output: Codable & Sendable
  associatedtype InternalState: Codable & Sendable
  associatedtype SomeTool: Tool where SomeTool.Use == Self

  typealias Status = CurrentValueStream<ToolUseExecutionStatus<Output>>

  init(
    callingTool: SomeTool,
    toolUseId: String,
    input: Input,
    isInputComplete: Bool,
    context: ToolExecutionContext,
    internalState: InternalState?,
    initialStatus: Status.Element?)

  /// The unique identifier of the tool use.
  var toolUseId: String { get }
  /// The input of the tool use.
  var input: Input { get }
  /// Whether the tool use is readonly or not.
  /// (tools that modify derived data are categorized as readonly. eg a build tool would be readonly).
  var isReadonly: Bool { get }
  /// The tool that is being used.
  var callingTool: SomeTool { get }
  /// The status of the execution of the tool use.
  var status: Status { get }
  /// The context in which the tool is executed.
  var context: ToolExecutionContext { get }
  /// Some internal state that the tool use needs to persist. It is not used outside of the tool use.
  var internalState: InternalState? { get }
  /// Whether the input has been entirely streamed.
  var isInputComplete: Bool { get }
  /// Update the input with the updated one.
  /// Note: the tool can expect this to be called only if `canInputBeStreamed` is true.
  /// - Parameters:
  ///   - inputUpdate: The update input containing all the data since it started streaming.
  ///   - isLast: Whether this is the last chunk of the input.
  func receive(inputUpdate: Data, isLast: Bool) throws
  /// Change the status to represent that the tool use is waiting for user's approval before being able to start the execution.
  func waitForApproval()
  /// Start the execution of the tool use. The execution should not start before this method is called.
  /// Note: the tool can expect this to be called after all the input has been received, and to not receive later calls to `receive(inputUpdate:)`.
  func startExecuting()
  /// Reject the tool use with an optional reason.
  func reject(reason: String?)
  /// Cancel the tool use, stopping any pending execution if possible.
  func cancel()
}

extension ToolUse {
  public var toolName: String { callingTool.name }

  public var toolDisplayName: String { callingTool.displayName }

  public var output: Output {
    get async throws {
      //       TODO: check why the iterator doesn't work nor completes if the value has already been set.
      if let result = try status.value.asOutput {
        return result
      }
      for await value in status.futureUpdates {
        if let result = try value.asOutput {
          return result
        }
      }
      throw AppError(message: "The tool use completed with no result.")
    }
  }

  public var currentOutput: Output? {
    get throws {
      try status.value.asOutput
    }
  }
}

extension ToolUse where InternalState == InternalState {
  public var internalState: InternalState? { nil }
}

// MARK: - StreamableTool

/// A tool that doesn't support streamed input, and that needs to have all its input to start a tool use.
public protocol NonStreamableTool: Tool where Use: NonStreamableToolUse { }

extension NonStreamableTool {
  public var canInputBeStreamed: Bool { false }
}

public protocol NonStreamableToolUse: ToolUse where SomeTool: NonStreamableTool {
  init(
    callingTool: SomeTool,
    toolUseId: String,
    input: Input,
    context: ToolExecutionContext,
    internalState: InternalState?,
    initialStatus: Status.Element?)
}

extension NonStreamableToolUse {
  public init(
    callingTool: SomeTool,
    toolUseId: String,
    input: Input,
    isInputComplete _: Bool,
    context: ToolExecutionContext,
    internalState: InternalState?,
    initialStatus: CurrentValueStream<ToolUseExecutionStatus<Output>>.Element? = nil)
  {
    self.init(
      callingTool: callingTool,
      toolUseId: toolUseId,
      input: input,
      context: context,
      internalState: internalState,
      initialStatus: initialStatus)
  }

  public var isInputComplete: Bool { true }
}

extension ToolUse where SomeTool: NonStreamableTool {
  public func receive(inputUpdate _: Data, isLast _: Bool) throws { }
}

/// An object that can be represented as a view
public protocol ViewRepresentable {
  associatedtype SomeView: View
  @MainActor
  var body: SomeView { get }
}

public final class AnyToolUseViewModel: Sendable, ViewRepresentable, StreamRepresentable {
  public init(_ viewModel: some Sendable & ViewRepresentable & StreamRepresentable) {
    _body = { AnyView(viewModel.body) }
    _streamRepresentation = { viewModel.streamRepresentation }
  }

  @MainActor
  public var body: some View { _body() }
  @MainActor
  public var streamRepresentation: String? { _streamRepresentation() }

  private let _body: @MainActor () -> AnyView
  private let _streamRepresentation: @MainActor () -> String?

}

// MARK: - DisplayableToolUse

/// A tool that can be displayed in th UI.
public protocol DisplayableToolUse: ToolUse, StreamRepresentable, ViewRepresentable where SomeView == ViewModel.SomeView {
  associatedtype ViewModel: ViewRepresentable & StreamRepresentable
  @MainActor
  var viewModel: ViewModel { get }
}

extension DisplayableToolUse {
  @MainActor
  public var body: ViewModel.SomeView { viewModel.body }

  @MainActor
  public var streamRepresentation: String? { viewModel.streamRepresentation }
}

// MARK: - ToolExecutionContext

/// The context in which a tool use has been created.
public struct ToolExecutionContext: Sendable, Codable {
  public init(threadId: String, project: URL? = nil, projectRoot: URL? = nil) {
    self.threadId = threadId
    self.project = project
    self.projectRoot = projectRoot
  }

  #if DEBUG
  public init(threadId: String = "mock-thread-id", projectRoot: URL? = nil) {
    self.threadId = threadId
    project = nil
    self.projectRoot = projectRoot
  }
  #endif

  /// The identifier for the chat thread where the tool is being used.
  public let threadId: String
  /// The path to the project that is being worked on.
  public let project: URL?
  /// The root of the project that is being worked on.
  /// For a Swift package this is the same as the project. For an xcodeproj this is the containing directory.
  public let projectRoot: URL?

}

/// The current context in which the tool use exists. The tool can modify relevant properties.
public protocol LiveToolExecutionContext: Sendable, AnyObject {
  /// The files whose content has been read/modified during the conversation.
  ///
  /// To ensure correct execution, we enforce that a file has to be read before being modified. This properties helps keep track of this.
  func knownFileContent(for path: URL) -> String?
  func set(knownFileContent: String, for path: URL)
  /// A properties that allows chat plugins (e.g. tools) to store state relevant to them within the context of a conversation.
  func pluginState<T: Codable & Sendable>(for key: String) -> T?
  func set(pluginState: some Codable & Sendable, for key: String)

  /// Note: `persist` is usually called when the tool knows that the state is not persisted otherwise,
  /// which means that implementation details are leaking between independent modules...
  /// Signals that the state has changed and should be persisted.
  func requestPersistence()
}

// MARK: - ToolUseExecutionStatus

public enum ToolUseExecutionStatus<Output: Codable & Sendable>: Sendable {
  case pendingApproval
  case approvalRejected(reason: String?)
  case notStarted
  case running
  case completed(Result<Output, Error>)

}

extension ToolUseExecutionStatus {
  var asOutput: Output? {
    get throws {
      if case .completed(let result) = self {
        return try result.get()
      }
      if case .approvalRejected(let reason) = self {
        if let reason, !reason.isEmpty {
          throw AppError(
            message: "User denied permission to execute this tool with the following explanation: `\(reason)`. Follow the user's direction or ask for clarification.")
        }
        throw AppError(
          message: "User denied permission to execute this tool. Please suggest an alternative approach or ask for clarification.")
      }
      return nil
    }
  }
}

// MARK: UpdatableToolUse

/// A tool use that can update its status in a standardized way.
///
/// Conforming to this protocol helps reduce redundant boilerplate that is provided by the extension.
public protocol UpdatableToolUse: ToolUse {
  var updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation { get }
}

extension UpdatableToolUse {
  public func reject(reason: String?) {
    updateStatus.yield(.approvalRejected(reason: reason))
  }

  public func waitForApproval() {
    updateStatus.yield(.pendingApproval)
  }

  public func complete(with error: Error) {
    updateStatus.complete(with: .failure(error))
  }
}

// MARK: - ExternalTool

public protocol ExternalTool: NonStreamableTool where Use: ExternalToolUse { }

public protocol ExternalToolUse: NonStreamableToolUse, UpdatableToolUse where SomeTool: ExternalTool {
  /// Set the output
  func receive(output: JSON.Value) throws
}

extension ExternalToolUse {

  public func startExecuting() {
    updateStatus.yield(.notStarted)
    updateStatus.yield(.running)
    // The execution is managed externally by Claude Code. Nothing to do here.
  }

  public func receive(output: JSON.Value, isSuccess: Bool) throws {
    if isSuccess {
      try receive(output: output)
    } else {
      guard case .string(let stringOutput) = output else {
        assertionFailure("Expected the output to be a string for an external tool use's error")
        return
      }
      updateStatus.complete(with: .failure(AppError(stringOutput)))
    }
  }

  public func cancel() {
    fail(with: CancellationError())
  }

  public func fail(with error: Error) {
    updateStatus.complete(with: .failure(error))
  }

  public func requireStringOutput(from output: JSON.Value) throws -> String {
    guard case .string(let stringOutput) = output else {
      let data = try JSONEncoder().encode(output)
      guard let str = String(data: data, encoding: .utf8) else {
        throw AppError("Could not parse output for tool \(toolName).")
      }
      defaultLogger.error("Could not parse output for tool \(toolName). Expected string but got \(str)")
      return str
    }
    return stringOutput
  }
}

extension Tool {

  /// Whether the tool's execution is externally managed (for instance Claude Code's tools are external).
  public var isExternalTool: Bool {
    self as? (any ExternalTool) != nil
  }
}

public enum StreamableInput<StreamingInput: Codable & Sendable, StreamedInput: Codable & Sendable>: Sendable {
  case streaming(_ input: StreamingInput)
  case streamed(_ input: StreamedInput)
}

extension AsyncStream.Continuation {
  public func complete<Output>(with result: Result<Output, Error>) where Element == ToolUseExecutionStatus<Output> {
    yield(.completed(result))
    finish()
  }
}
