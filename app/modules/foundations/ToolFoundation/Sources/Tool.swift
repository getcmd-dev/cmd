// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
// Re-export ChatFoundation as the protocols defined here depend on types from this module.
@_exported import ChatFoundation
import Combine
import ConcurrencyFoundation
import Foundation
import JSONFoundation
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
  associatedtype SomeTool: Tool where SomeTool.Use == Self

  typealias Status = CurrentValueStream<ToolUseExecutionStatus<Output>>

  init(
    callingTool: SomeTool,
    toolUseId: String,
    input: Input,
    isInputComplete: Bool,
    context: ToolExecutionContext,
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
  /// Whether the input has been entirely streamed.
  var isInputComplete: Bool { get }
  /// Update the input with the updated one.
  /// Note: the tool can expect this to be called only if `canInputBeStreamed` is true.
  /// - Parameters:
  ///   - inputUpdate: The update input containing all the data since it started streaming.
  ///   - isLast: Whether this is the last chunk of the input.
  func receive(inputUpdate: Data, isLast: Bool) throws
  /// Start the execution of the tool use. The execution should not start before this method is called.
  /// Note: the tool can expect this to be called after all the input has been received, and to not receive later calls to `receive(inputUpdate:)`.
  func startExecuting()
  /// Reject the tool use with an optional reason.
  func reject(reason: String?)
  /// Cancel the tool use, stopping any pending execution if possible.
  func cancel()
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

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: ToolUseCodingKeys.self)

    let callingTool = try container.decode(SomeTool.self, forKey: .callingTool)
    let toolUseId = try container.decode(String.self, forKey: .toolUseId)
    let input = try container.decode(Input.self, forKey: .input)
    let context = try container.decode(ToolExecutionContext.self, forKey: .context)
    let statusValue = try container.decode(ToolUseExecutionStatus<Output>.self, forKey: .status)
    let isInputComplete = try container.decode(Bool.self, forKey: .isInputComplete)

    self.init(
      callingTool: callingTool,
      toolUseId: toolUseId,
      input: input,
      isInputComplete: isInputComplete,
      context: context,
      initialStatus: statusValue)
  }

  public var toolName: String { callingTool.name }

  public var toolDisplayName: String { callingTool.displayName }

  public var output: Output {
    get async throws {
      //       TODO: check why the iterator doesn't work nor completes if the value has already been set.
      if let result = try status.value.asOutput {
        return result
      }
      for await value in status {
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

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: ToolUseCodingKeys.self)

    try container.encode(callingTool, forKey: .callingTool)
    try container.encode(toolUseId, forKey: .toolUseId)
    try container.encode(input, forKey: .input)
    try container.encode(context, forKey: .context)
    try container.encode(status.value, forKey: .status)
    try container.encode(isInputComplete, forKey: .isInputComplete)
  }
}

private enum ToolUseCodingKeys: String, CodingKey {
  case callingTool
  case toolUseId
  case input
  case context
  case status
  case isInputComplete
}

// MARK: - ExternalTool

public protocol ExternalTool: NonStreamableTool where Use: ExternalToolUse {
  
}

public protocol ExternalToolUse: NonStreamableToolUse where SomeTool: ExternalTool {
  /// Set the output
  func receive(output: JSON.Value) throws
}

extension Tool {
    
      
      /// Whether the tool's execution is externally managed (for instance Claude Code's tools are external).
      public var isExternalTool: Bool {
          self as? (any ExternalTool) != nil
      }
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
    initialStatus: Status.Element?)
}

extension NonStreamableToolUse {
  public init(
    callingTool: SomeTool,
    toolUseId: String,
    input: Input,
    isInputComplete _: Bool,
    context: ToolExecutionContext,
    initialStatus: CurrentValueStream<ToolUseExecutionStatus<Output>>.Element? = nil)
  {
    self.init(callingTool: callingTool, toolUseId: toolUseId, input: input, context: context, initialStatus: initialStatus)
  }

  public var isInputComplete: Bool { true }
}

extension ToolUse where SomeTool: NonStreamableTool {
  public func receive(inputUpdate _: Data, isLast _: Bool) throws { }
}

// MARK: - DisplayableToolUse

/// A tool that can be displayed in th UI.
public protocol DisplayableToolUse: ToolUse {
  associatedtype SomeView: View
  @MainActor
  var body: SomeView { get }
}

// MARK: - ToolExecutionContext

/// The context in which a tool use has been created.
public struct ToolExecutionContext: Sendable, Codable {
  /// The path to the project.
  public let project: URL?
  /// The path to the root of the project.
  /// For a Swift package this is the same as the project. For an xcodeproj this is the containing directory.
  public let projectRoot: URL?

  public init(project: URL?, projectRoot: URL?) {
    self.project = project
    self.projectRoot = projectRoot
  }
}

// MARK: - ToolUseExecutionStatus

public enum ToolUseExecutionStatus<Output: Codable & Sendable>: Sendable {
  case pendingApproval
  case approvalRejected(reason: String?)
  case notStarted
  case running
  case completed(Result<Output, Error>)

}

public enum StreamableInput<StreamingInput: Codable & Sendable, StreamedInput: Codable & Sendable>: Sendable {
  case streaming(_ input: StreamingInput)
  case streamed(_ input: StreamedInput)
}
