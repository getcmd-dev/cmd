// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LLMServiceInterface
import ToolFoundation

// MARK: - DefaultChatContext

final class DefaultChatContext: ChatContext {
  init(
    project: URL?,
    projectRoot: URL?,
    prepareToExecute: @escaping @Sendable (any ToolUse) async -> Void,
    needsApproval: @escaping @Sendable (any ToolUse) async -> Bool,
    requestToolApproval: @escaping @Sendable (any ToolUse) async throws -> Void,
    chatMode: ChatMode,
    threadId: String)
  {
    self.project = project
    self.projectRoot = projectRoot
    _prepareToExecute = prepareToExecute
    _needsApproval = needsApproval
    _requestToolApproval = requestToolApproval
    self.chatMode = chatMode
    self.threadId = threadId
  }

  let project: URL?
  let projectRoot: URL?
  let chatMode: ChatMode
  let threadId: String

  var toolExecutionContext: ToolExecutionContext {
    ToolExecutionContext(threadId: threadId, project: project, projectRoot: projectRoot)
  }

  func prepareToExecute(writingToolUse: any ToolUse) async {
    await _prepareToExecute(writingToolUse)
  }

  func needsApproval(for toolUse: any ToolUse) async -> Bool {
    await _needsApproval(toolUse)
  }

  func requestApproval(for toolUse: any ToolUse) async throws {
    try await _requestToolApproval(toolUse)
  }

  private let _needsApproval: @Sendable (any ToolUse) async -> Bool
  private let _prepareToExecute: @Sendable (any ToolUse) async -> Void
  private let _requestToolApproval: @Sendable (any ToolUse) async throws -> Void

}
