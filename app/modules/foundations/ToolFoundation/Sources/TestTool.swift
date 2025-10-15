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
public struct TestTool: NonStreamableTool {
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
  public struct Use: NonStreamableToolUse, Codable {

    public init(
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
      isReadonly = callingTool.isReadonly
      output = callingTool.output

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject

    public struct Input: Codable, Sendable {
      public init() { }
    }

    public typealias Output = JSON.Value

    public typealias Status = CurrentValueStream<ToolUseExecutionStatus<Output>>

    public let status: Status

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public let context: ToolExecutionContext
    public let callingTool: TestTool
    public let toolUseId: String
    public let isReadonly: Bool
    public let input: Input
    public let output: Result<Output, Error>

    public func startExecuting() {
      updateStatus.complete(with: output)
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
public struct GenericTestTool<I: Codable & Sendable, O: Codable & Sendable>: NonStreamableTool {
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
  public struct Use: NonStreamableToolUse, Codable {

    public init(
      callingTool: GenericTestTool<I, O>,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: EmptyObject? = nil,
      initialStatus _: Status.Element?)
    {
      self.toolUseId = toolUseId
      self.callingTool = callingTool
      self.context = context
      self.input = input
      output = callingTool.output
      isReadonly = callingTool.isReadonly
      status = .Just(.completed(callingTool.output))
    }

    public typealias InternalState = EmptyObject

    public typealias Input = I

    public let context: ToolExecutionContext
    public let callingTool: GenericTestTool<I, O>
    public let toolUseId: String
    public let isReadonly: Bool
    public let input: Input
    public let output: Result<O, Error>

    public let status: CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<O>>

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

// MARK: - TestStreamingTool

/// A test tool that supports streaming input for testing streaming tool use cases.
public struct TestStreamingTool<I: Codable & Sendable, O: Codable & Sendable>: Tool {
  public init(
    name: String = "TestStreamingTool",
    referenceId: String? = nil,
    availableByDefaultIn: Set<ChatMode> = [.agent, .ask])
  {
    self.name = name
    _referenceId = referenceId
    self.availableByDefaultIn = availableByDefaultIn
  }

  public final class Use: ToolUse, Codable, @unchecked Sendable {

    public init(
      callingTool: TestStreamingTool<I, O>,
      toolUseId: String,
      input: Input,
      isInputComplete: Bool,
      context: ToolExecutionContext,
      internalState _: EmptyObject? = nil,
      initialStatus: CurrentValueStream<ToolUseExecutionStatus<Output>>.Element? = nil)
    {
      self.toolUseId = toolUseId
      self.callingTool = callingTool
      self.input = input
      self.isInputComplete = isInputComplete
      self.context = context
      onReceiveInput = { }
      receivedInputs = [input]
      status = .Just(initialStatus ?? .notStarted)
    }

    public typealias InternalState = EmptyObject
    public typealias Input = I

    private(set) public var isInputComplete: Bool

    public let context: ToolExecutionContext

    public let callingTool: TestStreamingTool<I, O>
    public let toolUseId: String
    public let isReadonly = true
    private(set) public var input: Input
    public var onReceiveInput: @Sendable () -> Void
    private(set) public var receivedInputs: [I]

    public let status: CurrentValueStream<ToolUseExecutionStatus<O>>

    public func receive(inputUpdate: Data, isLast: Bool) throws {
      let newInput = try JSONDecoder().decode(I.self, from: inputUpdate)
      receivedInputs.append(newInput)
      input = newInput
      isInputComplete = isLast
      onReceiveInput()
    }

    public func startExecuting() { }

    public func reject(reason _: String?) { }

    public func cancel() { }

    public func waitForApproval() { }

  }

  public let canInputBeStreamed = true

  public let name: String
  public let availableByDefaultIn: Set<ChatMode>

  public var id: String { _referenceId ?? name }
  public var referenceId: String { id }

  public var displayName: String { name }
  public var shortDescription: String { "tool for testing" }

  public var description: String { "tool for testing" }
  public var inputSchema: JSON { .object([:]) }

  public func use(
    toolUseId: String,
    input: Data,
    isInputComplete: Bool,
    context: ToolExecutionContext)
    throws -> Use
  {
    let input = try JSONDecoder().decode(I.self, from: input)
    return Use(
      callingTool: self,
      toolUseId: toolUseId,
      input: input,
      isInputComplete: isInputComplete,
      context: context)
  }

  public func isAvailableByDefault(in mode: ChatFoundation.ChatMode) -> Bool {
    availableByDefaultIn.contains(mode)
  }

  private let _referenceId: String?

}

// MARK: - TestExternalTool

/// A test tool for external/MCP tools that receive output via the receive(output:) method.
public struct TestExternalTool: ExternalTool {

  public init(
    name: String = "TestExternalTool",
    referenceId: String? = nil,
    availableByDefaultIn: Set<ChatMode> = [.agent, .ask])
  {
    self.name = name
    _referenceId = referenceId
    self.availableByDefaultIn = availableByDefaultIn
  }

  // MARK: - TestExternalToolUse

  public struct Use: ExternalToolUse, Codable {
    public init(
      callingTool: TestExternalTool,
      toolUseId: String,
      input: EmptyObject,
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

    public typealias InternalState = EmptyObject
    public typealias Input = EmptyObject

    public let updateStatus: AsyncStream<ToolFoundation.ToolUseExecutionStatus<String>>.Continuation

    public let context: ToolExecutionContext
    public let callingTool: TestExternalTool
    public let toolUseId: String
    public let input: Input
    public let status: CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<String>>

    public var isReadonly: Bool { true }

    public func receive(output: JSON.Value) throws {
      let data = try JSONEncoder().encode(output)
      let stringOutput = try JSONDecoder().decode(String.self, from: data)
      updateStatus.complete(with: .success(stringOutput))
    }

  }

  public let name: String
  public let availableByDefaultIn: Set<ChatMode>

  public var id: String { _referenceId ?? name }
  public var referenceId: String { id }

  public var displayName: String { name }
  public var shortDescription: String { "external tool for testing" }

  public var description: String { "external tool for testing" }
  public var inputSchema: JSON { .object([:]) }

  public func isAvailableByDefault(in mode: ChatFoundation.ChatMode) -> Bool {
    availableByDefaultIn.contains(mode)
  }

  private let _referenceId: String?

}

#endif
