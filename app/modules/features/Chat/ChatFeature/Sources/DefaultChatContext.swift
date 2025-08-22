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
    prepareForWriteToolUse: @escaping @Sendable () async -> Void,
    requestToolApproval: @escaping @Sendable (any ToolUse) async throws -> Void,
    chatMode: ChatMode,
    threadId: String)
  {
    self.project = project
    self.projectRoot = projectRoot
    self.prepareForWriteToolUse = prepareForWriteToolUse
    self.requestToolApproval = requestToolApproval
    self.chatMode = chatMode
    self.threadId = threadId
  }

  let project: URL?
  let projectRoot: URL?
  let prepareForWriteToolUse: @Sendable () async -> Void
  let requestToolApproval: @Sendable (any ToolUse) async throws -> Void
  let chatMode: ChatMode
  let threadId: String

  var toolExecutionContext: ToolExecutionContext {
    ToolExecutionContext(threadId: threadId, project: project, projectRoot: projectRoot)
  }

}
