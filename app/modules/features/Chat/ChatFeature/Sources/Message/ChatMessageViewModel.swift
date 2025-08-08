// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import Foundation
import LLMServiceInterface
import Observation
import ServerServiceInterface
import ToolFoundation

// MARK: - ChatMessageViewModel

@Observable
@MainActor
final class ChatMessageViewModel: EquatableByIdentifier {

  init(
    id: UUID = UUID(),
    content: [ChatMessageContent],
    role: MessageRole,
    timestamp: Date = Date())
  {
    self.id = id
    self.content = content
    self.role = role
    self.timestamp = timestamp
  }

  let id: UUID
  var content: [ChatMessageContent]
  let role: MessageRole
  let timestamp: Date
}

// MARK: - ChatMessageContent

enum ChatMessageContent: Identifiable {
  case text(ChatMessageTextContent)
  case reasoning(ChatMessageReasoningContent)
  /// Messages that are relevant for the LLM but should not be shown to the user.
  case nonUserFacingText(ChatMessageTextContent)
  case toolUse(ChatMessageToolUseContent)
  case conversationSummary(ChatMessageTextContent)
  case internalContent(ChatMessageInternalContent)

  var id: UUID {
    switch self {
    case .text(let content):
      content.id
    case .nonUserFacingText(let content):
      content.id
    case .toolUse(let content):
      content.id
    case .reasoning(let content):
      content.id
    case .conversationSummary(let content):
      content.id
    case .internalContent(let content):
      content.id
    }
  }

  var asText: ChatMessageTextContent? {
    if case .text(let content) = self {
      return content
    }
    return nil
  }

  var asToolUse: ChatMessageToolUseContent? {
    if case .toolUse(let content) = self {
      return content
    }
    return nil
  }
}

// MARK: - ChatMessageContentWithRole

struct ChatMessageContentWithRole: Identifiable {
  init(
    content: ChatMessageContent,
    role: MessageRole,
    info: ChatMessageContentWithRoleModel.Info? = nil)
  {
    self.content = content
    self.role = role
    self.info = info
  }

  let content: ChatMessageContent
  let role: MessageRole
  let info: ChatMessageContentWithRoleModel.Info?

  var id: UUID {
    content.id
  }

  func with(info: ChatMessageContentWithRoleModel.Info) -> ChatMessageContentWithRole {
    ChatMessageContentWithRole(
      content: content,
      role: role,
      info: info)
  }
}

// MARK: - ChatMessageTextContent

@Observable
@MainActor
final class ChatMessageTextContent: EquatableByIdentifier {

  #if DEBUG
  convenience init(text: String, attachments: [AttachmentModel] = [], isStreaming: Bool = true) {
    self.init(projectRoot: URL(filePath: "/"), text: text, attachments: attachments, isStreaming: isStreaming)
  }

  convenience init(deltas: [String], attachments: [AttachmentModel] = [], isStreaming: Bool = true) {
    self.init(projectRoot: URL(filePath: "/"), deltas: deltas, attachments: attachments, isStreaming: isStreaming)
  }
  #endif

  init(
    id: UUID = UUID(),
    projectRoot: URL?,
    deltas: [String],
    attachments: [AttachmentModel] = [],
    isStreaming: Bool = true)
  {
    self.id = id
    self.attachments = attachments
    self.isStreaming = isStreaming
    formatter = TextFormatter(projectRoot: projectRoot)
    catchUp(deltas: deltas)
  }

  convenience init(projectRoot: URL?, text: String, attachments: [AttachmentModel] = [], isStreaming: Bool = true) {
    self.init(projectRoot: projectRoot, deltas: [text], attachments: attachments, isStreaming: isStreaming)
  }

  let id: UUID
  var attachments: [AttachmentModel]

  private(set) var elements: [TextFormatter.Element] = []

  let formatter: TextFormatter
  private(set) var isStreaming: Bool

  var projectRoot: URL? {
    formatter.projectRoot
  }

  var text: String {
    formatter.deltas.joined()
  }

  /// Update the content until it has caught up with the all the deltas.
  /// - Parameter deltas: All the deltas received since the beggining of the content (not just the new ones).
  func catchUp(deltas: [String]) {
    formatter.catchUp(deltas: deltas)
    elements = formatter.elements
  }

  #if DEBUG
  func ingest(delta: String) {
    formatter.ingest(delta: delta)
    elements = formatter.elements
  }
  #endif
  func finishStreaming() {
    isStreaming = false
  }

}

// MARK: - ChatMessageToolUseContent

@Observable
final class ChatMessageToolUseContent: EquatableByIdentifier {

  init(id: UUID = UUID(), toolUse: any ToolUse) {
    self.id = id
    self.toolUse = toolUse
  }

  let id: UUID
  let toolUse: any ToolUse

}

// MARK: - ChatMessageReasoningContent

@Observable
@MainActor
final class ChatMessageReasoningContent: EquatableByIdentifier {

  #if DEBUG
  convenience init(text: String, signature: String? = nil, isStreaming: Bool = true) {
    self.init(deltas: [text], signature: signature, isStreaming: isStreaming)
  }

  convenience init(deltas: [String], isStreaming: Bool = true) {
    self.init(deltas: deltas, signature: nil, isStreaming: isStreaming)
  }
  #endif

  init(id: UUID = UUID(), deltas: [String], signature: String?, isStreaming: Bool = true) {
    self.id = id
    self.signature = signature
    self.isStreaming = isStreaming
    catchUp(deltas: deltas)
  }

  let id: UUID

  private(set) var text = ""
  var signature: String?

  private(set) var isStreaming: Bool
  private(set) var reasoningDuration: TimeInterval?

  /// Update the content until it has caught up with the all the deltas.
  /// - Parameter deltas: All the deltas received since the beggining of the content (not just the new ones).
  func catchUp(deltas: [String]) {
    guard deltas.count > self.deltas.count else { return }
    for delta in deltas.suffix(from: self.deltas.count) {
      self.deltas.append(delta)
      text += delta
    }
  }

  func finishStreaming() {
    guard isStreaming else { return }
    isStreaming = false
    reasoningDuration = Date().timeIntervalSince(startedAt)
  }

  private let startedAt = Date()

  private var deltas: [String] = []

  #if DEBUG
  private func ingest(delta: String) {
    text += delta
  }
  #endif

}

typealias ChatMessageInternalContent = ChatMessageInternalContentModel

// MARK: - EquatableByIdentifier

public protocol EquatableByIdentifier: Equatable, Identifiable { }

extension EquatableByIdentifier {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}
