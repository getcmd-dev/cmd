// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LLMFoundation
import LLMServiceInterface
import ServerServiceInterface
import SettingsServiceInterface
import ThreadSafe
import ToolFoundation
@testable import LLMService

extension DefaultLLMService {

  convenience init(
    server: MockServer = MockServer(),
    settingsService: MockSettingsService = MockSettingsService(.init(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: LLMProviderSettings(
          apiKey: "anthropic-key",
          baseUrl: nil,
          createdOrder: 1),
        .openAI: LLMProviderSettings(
          apiKey: "openai-key",
          baseUrl: nil,
          createdOrder: 2),
      ])))
  {
    self.init(server: server as Server, settingsService: settingsService as SettingsService, userDefaults: MockUserDefaults())
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
          model: .claudeSonnet_4_0,
          context: TestChatContext(projectRoot: URL(filePath: "/path/to/root")))
        { stream in continuation
          .resume(returning: stream)
        }
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
          model: .claudeSonnet_4_0,
          context: TestChatContext(projectRoot: URL(filePath: "/path/to/root")))
        { stream in continuation
          .resume(returning: stream)
        }
      }
    }
  }
}

// MARK: - TestTool

struct TestTool<Input: Codable & Sendable, Output: Codable & Sendable>: NonStreamableTool {
  init(
    name: String = "TestTool",
    output: Result<Output, Error>,
    isReadonly: Bool = true,
    isAvailableInChatMode: @escaping @Sendable (ChatMode) -> Bool = { _ in true })
  {
    self.name = name
    self.isReadonly = isReadonly
    self.output = output
    self.isAvailableInChatMode = isAvailableInChatMode
  }

  init(name: String = "TestTool", output: Output) {
    self.init(name: name, output: .success(output))
  }

  // MARK: - TestToolUse

  @ThreadSafe
  struct Use: ToolUse, Codable {

    init(callingTool: TestTool<Input, Output>, toolUseId: String, input: Input, output: Result<Output, Error>, isReadonly: Bool) {
      self.toolUseId = toolUseId
      self.callingTool = callingTool
      self.input = input
      self.output = output
      self.isReadonly = isReadonly
      status = .Just(.completed(output))
    }

    init(from _: Decoder) throws {
      fatalError("Decoding not implemented for TestTool.Use")
    }

    let callingTool: TestTool<Input, Output>
    let toolUseId: String
    let isReadonly: Bool
    let input: Input
    let output: Result<Output, Error>

    let status: CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<Output>>

    func startExecuting() { }

    func reject(reason _: String?) { }

    func cancel() { }

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

  func use(toolUseId: String, input: Input, context _: ToolExecutionContext) -> Use {
    Use(callingTool: self, toolUseId: toolUseId, input: input, output: output, isReadonly: isReadonly)
  }

  private let output: Result<Output, Error>

}

struct TestStreamingTool<Input: Codable & Sendable, Output: Codable & Sendable>: Tool {
  init(
    name: String = "TestStreamingTool",
    output: Result<Output, Error>,
    isReadonly: Bool = true,
    isAvailableInChatMode: @escaping @Sendable (ChatMode) -> Bool = { _ in true })
  {
    self.name = name
    self.isReadonly = isReadonly
    self.output = output
    self.isAvailableInChatMode = isAvailableInChatMode
  }

  init(name: String = "TestStreamingTool", output: Output) {
    self.init(name: name, output: .success(output))
  }

  @ThreadSafe
  final class Use: ToolUse, Codable {
    init(
      callingTool: TestStreamingTool<Input, Output>,
      toolUseId: String,
      input: Input,
      output: Result<Output, Error>,
      isReadonly: Bool,
      hasReceivedAllInput: Bool = false)
    {
      self.toolUseId = toolUseId
      self.callingTool = callingTool
      self.input = input
      self.output = output
      self.isReadonly = isReadonly
      self.hasReceivedAllInput = hasReceivedAllInput
      onReceiveInput = { }
      receivedInputs = [input]
      status = .Just(.completed(output))
    }

    convenience init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: String.self)
      try self.init(
        callingTool: container.decode(TestStreamingTool<Input, Output>.self, forKey: "callingTool"),
        toolUseId: container.decode(String.self, forKey: "toolUseId"),
        input: container.decode(Input.self, forKey: "input"),
        output: container.decode(Result<Output, Error>.self, forKey: "output"),
        isReadonly: container.decode(Bool.self, forKey: "isReadonly"),
        hasReceivedAllInput: container.decodeIfPresent(Bool.self, forKey: "hasReceivedAllInput") ?? false)
    }

    let callingTool: TestStreamingTool<Input, Output>
    let toolUseId: String
    let isReadonly: Bool
    var hasReceivedAllInput: Bool
    var input: Input
    let output: Result<Output, Error>
    var onReceiveInput: @Sendable () -> Void
    var receivedInputs: [Input]

    let status: CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<Output>>

    func receive(inputUpdate: Data, isLast: Bool) throws {
      let newInput = try JSONDecoder().decode(Input.self, from: inputUpdate)
      receivedInputs.append(newInput)
      input = newInput
      hasReceivedAllInput = isLast
      onReceiveInput()
    }

    func startExecuting() { }

    func reject(reason _: String?) { }

    func cancel() { }

    func encode(to _: Encoder) throws {
      fatalError("Decoding not implemented for TestStreamingTool.Use")
    }

  }

  let canInputBeStreamed = true

  let name: String
  let isReadonly: Bool
  let isAvailableInChatMode: @Sendable (ChatMode) -> Bool

  var displayName: String { name }
  var shortDescription: String { "tool for testing" }

  var description: String { "tool for testing" }
  var inputSchema: JSON { .object([:]) }

  func use(
    toolUseId: String,
    input: Data,
    isInputComplete: Bool,
    context _: ToolFoundation.ToolExecutionContext)
    throws -> Use
  {
    let input = try JSONDecoder().decode(Input.self, from: input)
    let toolUse = Use(callingTool: self, toolUseId: toolUseId, input: input, output: output, isReadonly: isReadonly)
    if isInputComplete {
      toolUse.hasReceivedAllInput = true
    }
    return toolUse
  }

  func isAvailable(in _: ChatFoundation.ChatMode) -> Bool {
    true
  }

  private let output: Result<Output, Error>
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
    prepareForWriteToolUse: @escaping @Sendable () async -> Void = { },
    requestToolApproval: @escaping @Sendable (any ToolFoundation.ToolUse) async throws -> Void = { _ in })
  {
    self.project = project
    self.projectRoot = projectRoot
    self.chatMode = chatMode
    self.prepareForWriteToolUse = prepareForWriteToolUse
    self.requestToolApproval = requestToolApproval
  }

  let requestToolApproval: @Sendable (any ToolFoundation.ToolUse) async throws -> Void

  let project: URL?
  let projectRoot: URL?
  let chatMode: ChatMode

  let prepareForWriteToolUse: @Sendable () async -> Void
}
