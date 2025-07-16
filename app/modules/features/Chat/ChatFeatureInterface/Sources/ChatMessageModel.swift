// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import LLMServiceInterface
import LoggingServiceInterface
import ToolFoundation

// MARK: - ChatMessageModel

public struct ChatMessageModel: Sendable {

  public init(
    id: UUID,
    content: [ChatMessageContentModel],
    role: MessageRole,
    timestamp: Date)
  {
    self.id = id
    self.content = content
    self.role = role
    self.timestamp = timestamp
  }

  public let id: UUID
  public let content: [ChatMessageContentModel]
  public let role: MessageRole
  public let timestamp: Date
}

// MARK: - ChatMessageContentWithRoleModel

public struct ChatMessageContentWithRoleModel: Sendable {
  public init(
    content: ChatMessageContentModel,
    role: MessageRole,
    info: Info? = nil)
  {
    self.content = content
    self.role = role
    self.info = info
  }

  public struct Info: Sendable {
    public init(info: String, level: InfoLevel) {
      self.info = info
      self.level = level
    }

    public let info: String
    public let level: InfoLevel

    public enum InfoLevel: String, Sendable {
      case info
      case warning
      case error
    }
  }

  public let content: ChatMessageContentModel
  public let role: MessageRole
  public let info: Info?

}

// MARK: - ChatMessageContentModel

public enum ChatMessageContentModel: Sendable {
  case text(ChatMessageTextContentModel)
  case reasoning(ChatMessageReasoningContentModel)
  /// Messages that are relevant for the LLM but should not be shown to the user.
  case nonUserFacingText(ChatMessageTextContentModel)
  case toolUse(ChatMessageToolUseContentModel)
  case conversationSummary(ChatMessageTextContentModel)
}

// MARK: - ChatMessageTextContentModel

public struct ChatMessageTextContentModel: Identifiable, Sendable {

  public init(id: UUID, projectRoot: URL?, text: String, attachments: [AttachmentModel]) {
    self.id = id
    self.projectRoot = projectRoot
    self.text = text
    self.attachments = attachments
  }

  public let id: UUID
  public let projectRoot: URL?
  public let text: String
  public let attachments: [AttachmentModel]

}

// MARK: - ChatMessageToolUseContentModel

public struct ChatMessageToolUseContentModel: Identifiable, Sendable {

  public init(id: UUID, toolUse: any ToolUse) {
    self.id = id
    self.toolUse = toolUse
  }

  public let id: UUID
  public let toolUse: any ToolUse

}

// MARK: - ChatMessageReasoningContentModel

public struct ChatMessageReasoningContentModel: Identifiable, Sendable {

  public init(id: UUID, text: String, signature: String?, reasoningDuration: TimeInterval?) {
    self.id = id
    self.text = text
    self.signature = signature
    self.reasoningDuration = reasoningDuration
  }

  public let id: UUID
  public let text: String
  public let signature: String?
  public let reasoningDuration: TimeInterval?

}

// MARK: - MessageRole

public enum MessageRole: String, Encodable, Sendable {
  case user
  case assistant
  case system
  case tool
}
