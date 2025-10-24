// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
// Re-export ChatFoundation since StreamRepresentable and other types defined in Tool depend on it.
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
  /// A unique identifier for this tool that will never change.
  var id: String { get }
  /// The ID of the internal tool this maps to. For internal tools, this is the same as `id`.
  /// For external tools that map to internal tools, this points to the internal tool's ID.
  var referenceId: String { get }
  /// The name of the tool, used to identify it. It should only contain alphanumeric characters.
  var name: String { get }
  /// A description of what the tool does. The description of its input parameters is better suited for the `inputSchema` property.
  var description: String { get }
  /// The schema of the input parameters of the tool.
  var inputSchema: JSON { get }
  /// The tool display name
  var displayName: String { get }
  /// A short description of the tool (max 3 lines)
  var shortDescription: String { get }
  /// Whether this tool is available by default in a given chat mode.
  /// This describes the default behavior - users can override this in settings.
  func isAvailableByDefault(in mode: ChatMode) -> Bool

  // TODO: remove this eventually
  /// Whether the tool can be executed. When false, the tool can still be used to represent the action of an external agent.
  var canBeExecuted: Bool { get }
}

extension Tool {
  public typealias Input = Use.Input
  public typealias Output = Use.Output

  public var canBeExecuted: Bool { true }

  /// Use the tool with the given input. This doesn't start the execution, which happens when `startExecuting` is called on the tool use.
  public func use(toolUseId: String, input: Use.Input, context: ToolExecutionContext) -> Use {
    Use(
      callingTool: self,
      toolUseId: toolUseId,
      input: input,
      context: context,
      internalState: nil,
      initialStatus: nil)
  }

  public func use(toolUseId: String, input: Data, context: ToolExecutionContext) throws -> Use {
    let decodedInput = try JSONDecoder().decode(Input.self, from: input)
    return use(toolUseId: toolUseId, input: decodedInput, context: context)
  }

  /// Default implementation: available in all modes.
  /// Override this method to customize availability by mode.
  public func isAvailableByDefault(in _: ChatMode) -> Bool {
    true
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
  var updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation { get }
  /// The context in which the tool is executed.
  var context: ToolExecutionContext { get }
  /// Some internal state that the tool use needs to persist. It is not used outside of the tool use.
  var internalState: InternalState? { get }
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
  public var toolId: String { callingTool.id }
  public var toolReferenceId: String { callingTool.referenceId }
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

  /// Update the tool state when a succesful output has been received.
  /// This method is called when the tool is run by an external agent.
  public func receive(externalSuccess: JSON.Value) {
    do {
      let data = try JSONEncoder().encode(externalSuccess)
      let output = try JSONDecoder().decode(Output.self, from: data)
      updateStatus.complete(with: .success(output))
    } catch {
      updateStatus.complete(with: .failure(error))
    }
  }
}

extension ToolUse where InternalState == EmptyObject {
  public var internalState: InternalState? { nil }
}

// MARK: - ViewRepresentable

/// An object that can be represented as a view
public protocol ViewRepresentable {
  associatedtype SomeView: View
  @MainActor
  var body: SomeView { get }
}

// MARK: - AnyToolUseViewModel

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

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    threadId = try container.decode(String.self, forKey: .threadId)
    project = try container.decodeIfPresent(String.self, forKey: .project).map { URL(filePath: $0) }
    projectRoot = try container.decodeIfPresent(String.self, forKey: .projectRoot).map { URL(filePath: $0) }
  }

  public enum CodingKeys: CodingKey {
    case threadId
    case project
    case projectRoot
  }

  /// The identifier for the chat thread where the tool is being used.
  public let threadId: String
  /// The path to the project that is being worked on.
  public let project: URL?
  /// The root of the project that is being worked on.
  /// For a Swift package this is the same as the project. For an xcodeproj this is the containing directory.
  public let projectRoot: URL?

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(threadId, forKey: .threadId)
    try container.encodeIfPresent(project?.path, forKey: .project)
    try container.encodeIfPresent(projectRoot?.path, forKey: .projectRoot)
  }

}

// MARK: - LiveToolExecutionContext

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

extension ToolUse {
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

// MARK: - ToolError

public struct ToolError: Error, CustomNSError, LocalizedError {
  public init(_ value: JSON.Value) {
    self.value = value
  }

  public let value: JSON.Value

  public var errorDescription: String? {
    Self.errorDescription(for: value)
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: Self.errorDescription(for: value),
    ]
  }

  public var localizedDescription: String {
    Self.errorDescription(for: value)
  }

  private static func errorDescription(for value: JSON.Value) -> String {
    switch value {
    case .string(let value):
      value
    case .array(let array):
      array.map(Self.errorDescription(for:)).joined(separator: ", ")
    case .number(let value):
      "\(value)"
    case .bool(let value):
      "\(value)"
    case .null:
      "null"
    case .object(let value):
      value
        .mapValues(Self.errorDescription(for:))
        .map({ "\($0.key): \($0.value)" })
        .joined(separator: "\n")
    }
  }
}

extension ToolUse {

  public func receive(output: JSON.Value, isSuccess: Bool) throws {
    if isSuccess {
      receive(externalSuccess: output)
    } else {
      if case .string(let stringOutput) = output {
        updateStatus.complete(with: .failure(AppError(stringOutput)))
      } else {
        updateStatus.complete(with: .failure(ToolError(output)))
      }
    }
  }

  public func cancel() {
    fail(with: CancellationError())
  }

  public func fail(with error: Error) {
    updateStatus.complete(with: .failure(error))
  }

  // TODO: remove after removing all Claude Code tools.
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

extension AsyncStream.Continuation {
  public func complete<Output>(with result: Result<Output, Error>) where Element == ToolUseExecutionStatus<Output> {
    yield(.completed(result))
    finish()
  }
}
