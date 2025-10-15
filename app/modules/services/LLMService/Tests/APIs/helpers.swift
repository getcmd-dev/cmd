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
        .anthropic: AIProviderSettings(
          apiKey: "anthropic-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "openai-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ])),
    shellService: MockShellService = MockShellService(),
    fileManager: MockFileManager = MockFileManager(),
    llmModelsManager: MockAIModelsManager = MockAIModelsManager())
  {
    self.init(
      server: server as LocalServer,
      settingsService: settingsService as SettingsService,
      userDefaults: MockUserDefaults(),
      shellService: shellService,
      fileManager: fileManager,
      llmModelsManager: llmModelsManager)
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

// NOTE: Test tools are now defined in ToolFoundation/Sources/TestTool.swift
// Use GenericTestTool<I, O>, TestStreamingTool<I, O>, and TestExternalTool from there.

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
