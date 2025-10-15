// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFeatureInterface
import ChatServiceInterface
import CheckpointServiceInterface
import Dependencies
import FileSuggestionServiceInterface
import Foundation
import JSONFoundation
import LLMServiceInterface

// MARK: - ChatThreadViewModel Extensions

extension ChatThreadViewModel {
  convenience init(from persistentModel: ChatThreadModel) {
    self.init(
      id: persistentModel.id,
      name: persistentModel.name,
      messages: persistentModel.messages.map { .init(from: $0) },
      events: persistentModel.events.map { .init(from: $0) },
      projectInfo: persistentModel.projectInfo,
      knownFilesContent: persistentModel.knownFilesContent,
      createdAt: persistentModel.createdAt)
  }

  var persistentModel: ChatThreadModel {
    .init(
      id: id,
      name: name ?? "new thread",
      messages: messages.map(\.persistentModel),
      events: events.map(\.persistentModel),
      projectInfo: projectInfo,
      knownFilesContent: context.knownFilesContent,
      createdAt: createdAt)
  }

}

// MARK: - ChatMessage Extensions

extension ChatMessageViewModel {
  convenience init(from persistentModel: ChatMessageModel) {
    self.init(
      id: persistentModel.id,
      content: persistentModel.content.map { .init(from: $0) },
      role: persistentModel.role,
      timestamp: persistentModel.timestamp)
  }

  var persistentModel: ChatMessageModel {
    ChatMessageModel(
      id: id,
      content: content.map(\.persistentModel),
      role: role,
      timestamp: timestamp)
  }

}

// MARK: - ChatMessageContent Extensions

extension ChatMessageContent {
  @MainActor
  init(from persistentModel: ChatMessageContentModel) {
    switch persistentModel {
    case .text(let text):
      self = .text(.init(
        id: text.id,
        projectRoot: text.projectRoot,
        deltas: [text.text],
        attachments: text.attachments,
        isStreaming: false))

    case .reasoning(let reasoning):
      self = .reasoning(.init(id: reasoning.id, deltas: [reasoning.text], signature: reasoning.signature, isStreaming: false))

    case .nonUserFacingText(let nonUserFacingText):
      self = .nonUserFacingText(.init(
        id: nonUserFacingText.id,
        projectRoot: nonUserFacingText.projectRoot,
        deltas: [nonUserFacingText.text],
        attachments: nonUserFacingText.attachments,
        isStreaming: false))

    case .toolUse(let toolUseContent):
      self = .toolUse(.init(
        id: toolUseContent.id,
        toolUse: toolUseContent.toolUse))

    case .conversationSummary(let summary):
      self = .conversationSummary(.init(
        id: summary.id,
        projectRoot: nil,
        deltas: [summary.text]))

    case .internalContent(let content):
      self = .internalContent(content)
    }
  }

  @MainActor
  var persistentModel: ChatMessageContentModel {
    switch self {
    case .text(let text):
      .text(.init(id: text.id, projectRoot: text.projectRoot, text: text.text, attachments: text.attachments))

    case .reasoning(let reasoning):
      .reasoning(.init(
        id: reasoning.id,
        text: reasoning.text,
        signature: reasoning.signature,
        reasoningDuration: reasoning.reasoningDuration))

    case .nonUserFacingText(let nonUserFacingText):
      .nonUserFacingText(.init(
        id: nonUserFacingText.id,
        projectRoot: nonUserFacingText.projectRoot,
        text: nonUserFacingText.text,
        attachments: nonUserFacingText.attachments))

    case .toolUse(let toolUseContent):
      .toolUse(.init(id: toolUseContent.id, toolUse: toolUseContent.toolUse))

    case .conversationSummary(let summary):
      .conversationSummary(ChatMessageTextContentModel(
        id: summary.id,
        projectRoot: nil,
        text: summary.text,
        attachments: []))

    case .internalContent(let content):
      .internalContent(content)
    }
  }

}

// MARK: - ChatEvent Extensions

extension ChatEvent {
  @MainActor
  init(from persistentModel: ChatEventModel) {
    switch persistentModel {
    case .checkpoint(let checkpoint):
      self = .checkpoint(.init(
        id: checkpoint.id,
        message: checkpoint.message,
        projectRoot: checkpoint.projectRoot,
        taskId: checkpoint.taskId))

    case .message(let message):
      self = .message(.init(content: .init(from: message.content), role: message.role, info: message.info))
    }
  }

  @MainActor
  var persistentModel: ChatEventModel {
    switch self {
    case .message(let message):
      .message(.init(content: message.content.persistentModel, role: message.role, info: message.info))

    case .checkpoint(let checkpoint):
      .checkpoint(.init(
        id: checkpoint.id,
        message: checkpoint.message,
        projectRoot: checkpoint.projectRoot,
        taskId: checkpoint.taskId))
    }
  }

}
