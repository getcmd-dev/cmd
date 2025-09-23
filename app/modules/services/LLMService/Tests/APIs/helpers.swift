// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LLMFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe
import ToolFoundation
@testable import LLMService

extension DefaultLLMService {

  convenience init(
    server: MockLocalServer = MockLocalServer(),
    settingsService: MockSettingsService = MockSettingsService(.init(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: LLMProviderSettings(
          apiKey: "anthropic-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: LLMProviderSettings(
          apiKey: "openai-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ])),
    shellService: MockShellService = MockShellService())
  {
    self.init(
      server: server as LocalServer,
      settingsService: settingsService as SettingsService,
      userDefaults: MockUserDefaults(),
      shellService: shellService)
  }

  func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool] = [])
    async throws -> UpdateStream
  {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        _ = try await sendMessage(
          messageHistory: messageHistory,
          tools: tools,
          model: .claudeSonnet,
          chatMode: .ask,
          context: TestChatContext(projectRoot: URL(filePath: "/path/to/root")),
          handleUpdateStream: { stream in continuation
            .resume(returning: stream)
          })
      }
    }
  }

  func sendOneMessage(
    messageHistory: [Schema.Message],
    tools: [any Tool] = [])
    async throws -> CurrentValueStream<AssistantMessage>
  {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        _ = try await sendOneMessage(
          messageHistory: messageHistory,
          tools: tools,
          model: .claudeSonnet,
          chatMode: .ask,
          context: TestChatContext(projectRoot: URL(filePath: "/path/to/root")),
          handleUpdateStream: { stream in
            continuation.resume(returning: stream)
          },
          handleUsageInfo: { _ in })
      }
    }
  }
}

// MARK: - TestTool

struct TestTool<I: Codable & Sendable, O: Codable & Sendable>: NonStreamableTool {
  init(
    name: String = "TestTool",
    output: Result<O, Error>,
    isReadonly: Bool = true,
    isAvailableInChatMode: @escaping @Sendable (ChatMode) -> Bool = { _ in true })
  {
    self.name = name
    self.isReadonly = isReadonly
    self.output = output
    self.isAvailableInChatMode = isAvailableInChatMode
  }

  init(name: String = "TestTool", output: O) {
    self.init(name: name, output: .success(output))
  }

  // MARK: - TestToolUse

  @ThreadSafe
  struct Use: NonStreamableToolUse, Codable {

    init(
      callingTool: TestTool<I, O>,
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

    init(from _: Decoder) throws {
      fatalError("Decoding not implemented for TestTool.Use")
    }

    typealias InternalState = EmptyObject

    typealias Input = I

    let context: ToolExecutionContext
    let callingTool: TestTool<I, O>
    let toolUseId: String
    let isReadonly: Bool
    let input: Input
    let output: Result<O, Error>

    let status: CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<O>>

    func startExecuting() { }

    func reject(reason _: String?) { }

    func cancel() { }

    func waitForApproval() { }

    func encode(to _: Encoder) throws {
      fatalError("Decoding not implemented for TestTool.Use")
    }

  }

  let name: String
  let isReadonly: Bool
  let isAvailableInChatMode: @Sendable (ChatMode) -> Bool

  var displayName: String { name }
  var shortDescription: String { "tool for testing" }

  var description: String { "tool for testing" }
  var inputSchema: JSON { .object([:]) }

  func isAvailable(in _: ChatFoundation.ChatMode) -> Bool {
    true
  }

  private let output: Result<O, Error>

}

// MARK: - TestStreamingTool

struct TestStreamingTool<I: Codable & Sendable, O: Codable & Sendable>: Tool {
  init(name: String = "TestStreamingTool") {
    self.name = name
  }

  @ThreadSafe
  final class Use: ToolUse, Codable {

    init(
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

    typealias InternalState = EmptyObject
    typealias Input = I

    private(set) var isInputComplete: Bool

    let context: ToolExecutionContext

    let callingTool: TestStreamingTool<I, O>
    let toolUseId: String
    let isReadonly = true
    private(set) var input: Input
    var onReceiveInput: @Sendable () -> Void
    private(set) var receivedInputs: [I]

    let status: CurrentValueStream<ToolUseExecutionStatus<O>>

    func receive(inputUpdate: Data, isLast: Bool) throws {
      let newInput = try JSONDecoder().decode(I.self, from: inputUpdate)
      receivedInputs.append(newInput)
      input = newInput
      isInputComplete = isLast
      onReceiveInput()
    }

    func startExecuting() { }

    func reject(reason _: String?) { }

    func cancel() { }

    func waitForApproval() { }

    func encode(to _: Encoder) throws {
      fatalError("Decoding not implemented for TestStreamingTool.Use")
    }

  }

  let canInputBeStreamed = true

  let name: String

  var displayName: String { name }
  var shortDescription: String { "tool for testing" }

  var description: String { "tool for testing" }
  var inputSchema: JSON { .object([:]) }

  func use(
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

  func isAvailable(in _: ChatFoundation.ChatMode) -> Bool {
    true
  }
}

// MARK: - TestExternalTool

struct TestExternalTool: ExternalTool {

  init(
    name: String = "TestExternalTool")
  {
    self.name = name
  }

  // MARK: - TestToolUse

  ///  @ThreadSafe
  struct Use: ExternalToolUse, Codable {
    init(
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

    typealias InternalState = EmptyObject
    typealias Input = EmptyObject

    var updateStatus: AsyncStream<ToolFoundation.ToolUseExecutionStatus<String>>.Continuation

    let context: ToolExecutionContext
    let callingTool: TestExternalTool
    let toolUseId: String
    let input: Input
    let status: CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<String>>

    var isReadonly: Bool { true }

    func receive(output: JSON.Value) throws {
      let data = try JSONEncoder().encode(output)
      let stringOutput = try JSONDecoder().decode(String.self, from: data)
      updateStatus.complete(with: .success(stringOutput))
    }

  }

  let name: String

  var displayName: String { name }
  var shortDescription: String { "external tool for testing" }

  var description: String { "external tool for testing" }
  var inputSchema: JSON { .object([:]) }

  func isAvailable(in _: ChatFoundation.ChatMode) -> Bool {
    true
  }
}

extension [AssistantMessageContent] {
  mutating func append(toolUse: any ToolUse) {
    append(.tool(ToolUseMessage(toolUse: toolUse)))
  }
}

// MARK: - TestToolInput

struct TestToolInput: Codable & Sendable {
  let file: String
  let keywords: [String]?
}

let okServerResponse = Data()

// MARK: - TestChatContext

struct TestChatContext: ChatContext {
  init(
    project: URL? = nil,
    projectRoot: URL,
    chatMode: ChatMode = .ask,
    prepareToExecuteHandler: @escaping @Sendable (any ToolFoundation.ToolUse) async -> Void = { _ in },
    needsApprovalHandler: @escaping @Sendable (any ToolFoundation.ToolUse) async -> Bool = { _ in false },
    requestApprovalHandler: @escaping @Sendable (any ToolFoundation.ToolUse) async throws -> Void = { _ in })
  {
    self.project = project
    self.projectRoot = projectRoot
    self.chatMode = chatMode
    self.prepareToExecuteHandler = prepareToExecuteHandler
    self.needsApprovalHandler = needsApprovalHandler
    self.requestApprovalHandler = requestApprovalHandler
    toolExecutionContext = ToolExecutionContext(projectRoot: projectRoot)
  }

  let project: URL?
  let projectRoot: URL?
  let chatMode: ChatMode
  let toolExecutionContext: ToolExecutionContext

  func prepareToExecute(writingToolUse: any ToolUse) async {
    await prepareToExecuteHandler(writingToolUse)
  }

  func needsApproval(for toolUse: any ToolUse) async -> Bool {
    await needsApprovalHandler(toolUse)
  }

  func requestApproval(for toolUse: any ToolUse) async throws {
    try await requestApprovalHandler(toolUse)
  }

  private let prepareToExecuteHandler: @Sendable (any ToolUse) async -> Void
  private let needsApprovalHandler: @Sendable (any ToolFoundation.ToolUse) async -> Bool
  private let requestApprovalHandler: @Sendable (any ToolFoundation.ToolUse) async throws -> Void

}
