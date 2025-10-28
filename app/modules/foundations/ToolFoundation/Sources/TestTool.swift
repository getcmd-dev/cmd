// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

#if DEBUG

import AppFoundation
import ChatFoundation
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import ThreadSafe

// MARK: - TestTool (Non-Streaming)

/// A simple test tool for unit tests that completes immediately with a predefined output.
/// This tool supports both JSON.Value output (default) and generic typed output.
public struct TestTool: Tool {
  public init(
    name: String = "TestTool",
    referenceId: String? = nil,
    availableByDefaultIn: Set<ChatFoundation.ChatMode> = [.agent, .ask],
    isReadonly: Bool = false,
    output: Result<JSON.Value, Error> = .success(.null))
  {
    self.name = name
    _referenceId = referenceId
    self.availableByDefaultIn = availableByDefaultIn
    self.isReadonly = isReadonly
    self.output = output
  }

  // MARK: - TestToolUse

  @ThreadSafe
  public struct Use: ToolUse, Codable {

    public init(
      callingTool: TestTool,
      toolUseId: String,
      inputResult: Result<Input, ToolDecodingError>,
      context: ToolExecutionContext,
      internalState _: EmptyObject? = nil,
      initialStatus: Status.Element?)
    {
      self.toolUseId = toolUseId
      self.callingTool = callingTool
      self.context = context
      isReadonly = callingTool.isReadonly
      output = callingTool.output

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted(input: try! inputResult.get()))
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject

    public typealias Input = JSON.Value

    public typealias Output = JSON.Value

    public typealias Status = CurrentValueStream<ToolUseExecutionStatus<Input, Output>>

    public let status: Status

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Input, Output>>.Continuation

    public let context: ToolExecutionContext
    public let callingTool: TestTool
    public let toolUseId: String
    public let isReadonly: Bool
    public let output: Result<Output, Error>

    public func startExecuting() {
      guard let input = status.value.input else { return }
      updateStatus.complete(with: output, input: input)
    }

    public func reject(reason _: String?) { }

    public func cancel() { }

    public func waitForApproval() { }

  }

  public let name: String
  public let availableByDefaultIn: Set<ChatFoundation.ChatMode>
  public let isReadonly: Bool

  public var id: String { _referenceId ?? name }
  public var referenceId: String { id }

  public var displayName: String { name }
  public var shortDescription: String { "tool for testing" }

  public var description: String { "tool for testing" }
  public var inputSchema: JSON { .object([:]) }

  public func isAvailableByDefault(in mode: ChatFoundation.ChatMode) -> Bool {
    availableByDefaultIn.contains(mode)
  }

  private let _referenceId: String?
  private let output: Result<JSON.Value, Error>

}

// MARK: - GenericTestTool (Non-Streaming with Generic Types)

/// A test tool with generic input and output types for more type-safe testing.
public struct GenericTestTool<I: Codable & Sendable, O: Codable & Sendable>: Tool {
  public init(
    name: String = "GenericTestTool",
    referenceId: String? = nil,
    output: Result<O, Error>,
    isReadonly: Bool = true,
    availableByDefaultIn: Set<ChatMode> = [.agent, .ask])
  {
    self.name = name
    _referenceId = referenceId
    self.isReadonly = isReadonly
    self.output = output
    self.availableByDefaultIn = availableByDefaultIn
  }

  public init(
    name: String = "GenericTestTool",
    referenceId: String? = nil,
    output: O,
    isReadonly: Bool = true,
    availableByDefaultIn: Set<ChatMode> = [.agent, .ask])
  {
    self.init(
      name: name,
      referenceId: referenceId,
      output: .success(output),
      isReadonly: isReadonly,
      availableByDefaultIn: availableByDefaultIn)
  }

  // MARK: - GenericTestToolUse

  @ThreadSafe
  public struct Use: ToolUse, Codable {
    public init(
      callingTool: GenericTestTool<I, O>,
      toolUseId: String,
      inputResult: Result<Input, ToolDecodingError>,
      context: ToolExecutionContext,
      internalState _: EmptyObject? = nil,
      initialStatus: Status.Element?)
    {
      self.toolUseId = toolUseId
      self.callingTool = callingTool
      self.context = context
      output = callingTool.output
      isReadonly = callingTool.isReadonly

      // Extract input from inputResult, using initialStatus if available
      let finalStatus: Status.Element =
        if let initialStatus {
          initialStatus
        } else {
          switch inputResult {
          case .success(let input):
            .completed(input: input, result: callingTool.output)
          case .failure(let error):
            .failedToDecode(error: error)
          }
        }

      let (stream, updateStatus) = Status.makeStream(initial: finalStatus)
      updateStatus.finish()
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject

    public typealias Input = I

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<I, O>>.Continuation

    public let context: ToolExecutionContext
    public let callingTool: GenericTestTool<I, O>
    public let toolUseId: String
    public let isReadonly: Bool
    public let output: Result<O, Error>

    public let status: CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<I, O>>

    public func startExecuting() { }

    public func reject(reason _: String?) { }

    public func cancel() { }

    public func waitForApproval() { }

  }

  public let name: String
  public let isReadonly: Bool
  public let availableByDefaultIn: Set<ChatMode>

  public var id: String { _referenceId ?? name }
  public var referenceId: String { id }

  public var displayName: String { name }
  public var shortDescription: String { "tool for testing" }

  public var description: String { "tool for testing" }
  public var inputSchema: JSON { .object([:]) }

  public func isAvailableByDefault(in mode: ChatFoundation.ChatMode) -> Bool {
    availableByDefaultIn.contains(mode)
  }

  private let _referenceId: String?

  private let output: Result<O, Error>

}

#endif
