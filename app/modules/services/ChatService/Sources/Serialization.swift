// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import CheckpointServiceInterface
import Foundation
import LLMServiceInterface
import ServerServiceInterface
import ToolFoundation

// MARK: - ChatThreadModel + Codable

extension ChatThreadModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      name: container.decode(String.self, forKey: .name),
      messages: container.decode([ChatMessageModel].self, forKey: .messages),
      events: container.decode([ChatEventModel].self, forKey: .events),
      projectInfo: container.decodeIfPresent(ChatThreadModel.SelectedProjectInfo.self, forKey: .projectInfo),
      knownFilesContent: container.decodeIfPresent([String: String].self, forKey: .knownFilesContent) ?? [:],
      createdAt: container.decode(Date.self, forKey: .createdAt))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(messages, forKey: .messages)
    try container.encode(events, forKey: .events)
    try container.encodeIfPresent(projectInfo, forKey: .projectInfo)
    try container.encode(knownFilesContent, forKey: .knownFilesContent)
    try container.encode(createdAt, forKey: .createdAt)
  }

  enum CodingKeys: String, CodingKey {
    case id, name, messages, events, projectInfo, knownFilesContent, createdAt
  }
}

// MARK: - ChatThreadModel.SelectedProjectInfo + Codable

extension ChatThreadModel.SelectedProjectInfo: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      path: container.decode(URL.self, forKey: .path),
      dirPath: container.decode(URL.self, forKey: .dirPath))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(path, forKey: .path)
    try container.encode(dirPath, forKey: .dirPath)
  }

  enum CodingKeys: String, CodingKey {
    case path, dirPath
  }
}

// MARK: - ChatMessageModel + Codable

extension ChatMessageModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      content: container.decode([ChatMessageContentModel].self, forKey: .content),
      role: container.decode(MessageRole.self, forKey: .role),
      timestamp: container.decode(Date.self, forKey: .timestamp))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(content, forKey: .content)
    try container.encode(role, forKey: .role)
    try container.encode(timestamp, forKey: .timestamp)
  }

  enum CodingKeys: String, CodingKey {
    case id, content, role, timestamp
  }
}

// MARK: - ChatMessageContentWithRoleModel + Codable

extension ChatMessageContentWithRoleModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      content: container.decode(ChatMessageContentModel.self, forKey: .content),
      role: container.decode(MessageRole.self, forKey: .role),
      info: container.decodeIfPresent(Info.self, forKey: .info))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(content, forKey: .content)
    try container.encode(role, forKey: .role)
    try container.encodeIfPresent(info, forKey: .info)
  }

  enum CodingKeys: String, CodingKey {
    case content, role, info
  }
}

// MARK: - ChatMessageContentWithRoleModel.Info + Codable

extension ChatMessageContentWithRoleModel.Info: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      info: container.decode(String.self, forKey: .info),
      level: container.decode(InfoLevel.self, forKey: .level))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(info, forKey: .info)
    try container.encode(level, forKey: .level)
  }

  enum CodingKeys: String, CodingKey {
    case info, level
  }
}

// MARK: - ChatMessageContentWithRoleModel.Info.InfoLevel + Codable

extension ChatMessageContentWithRoleModel.Info.InfoLevel: Codable { }

// MARK: - ChatMessageContentModel + Codable

extension ChatMessageContentModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "text":
      let data = try container.decode(ChatMessageTextContentModel.self, forKey: .data)
      self = .text(data)

    case "reasoning":
      let data = try container.decode(ChatMessageReasoningContentModel.self, forKey: .data)
      self = .reasoning(data)

    case "nonUserFacingText":
      let data = try container.decode(ChatMessageTextContentModel.self, forKey: .data)
      self = .nonUserFacingText(data)

    case "toolUse":
      let data = try container.decode(ChatMessageToolUseContentModel.self, forKey: .data)
      self = .toolUse(data)

    case "conversationSummary":
      let data = try container.decode(ChatMessageTextContentModel.self, forKey: .data)
      self = .conversationSummary(data)

    case "internalContent":
      let data = try container.decode(ChatMessageInternalContentModel.self, forKey: .data)
      self = .internalContent(data)

    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Unknown message content type: \(type)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .text(let data):
      try container.encode("text", forKey: .type)
      try container.encode(data, forKey: .data)

    case .reasoning(let data):
      try container.encode("reasoning", forKey: .type)
      try container.encode(data, forKey: .data)

    case .nonUserFacingText(let data):
      try container.encode("nonUserFacingText", forKey: .type)
      try container.encode(data, forKey: .data)

    case .toolUse(let data):
      try container.encode("toolUse", forKey: .type)
      try container.encode(data, forKey: .data)

    case .conversationSummary(let data):
      try container.encode("conversationSummary", forKey: .type)
      try container.encode(data, forKey: .data)

    case .internalContent(let content):
      try container.encode("internalContent", forKey: .type)
      try container.encode(content, forKey: .data)
    }
  }

  enum CodingKeys: String, CodingKey {
    case type
    case data
  }

}

// MARK: - ChatMessageTextContentModel + Codable

extension ChatMessageTextContentModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      projectRoot: container.decodeIfPresent(URL.self, forKey: .projectRoot),
      text: container.decode(String.self, forKey: .text),
      attachments: container.decode([AttachmentModel].self, forKey: .attachments))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(projectRoot, forKey: .projectRoot)
    try container.encode(text, forKey: .text)
    try container.encode(attachments, forKey: .attachments)
  }

  enum CodingKeys: String, CodingKey {
    case id, projectRoot, text, attachments
  }

}

// MARK: - ChatMessageToolUseContentModel + Codable

extension ChatMessageToolUseContentModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let tool = try container.decodeAnyTool(forKey: .callingTool)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      toolUse: container.decode(useOf: tool, forKey: .toolUse))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(toolUse.callingTool, forKey: .callingTool)
    try container.encode(toolUse, forKey: .toolUse)
  }

  enum CodingKeys: String, CodingKey {
    case id, toolUse, callingTool
  }

}

// MARK: - ChatMessageReasoningContentModel + Codable

extension ChatMessageReasoningContentModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      text: container.decode(String.self, forKey: .text),
      signature: container.decodeIfPresent(String.self, forKey: .signature),
      reasoningDuration: container.decodeIfPresent(TimeInterval.self, forKey: .reasoningDuration))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(text, forKey: .text)
    try container.encodeIfPresent(signature, forKey: .signature)
    try container.encodeIfPresent(reasoningDuration, forKey: .reasoningDuration)
  }

  enum CodingKeys: String, CodingKey {
    case id, text, signature, reasoningDuration
  }

}

// MARK: - ChatMessageInternalContentModel + Codable

extension ChatMessageInternalContentModel: Codable {

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      container.decode(Schema.InternalContent.self, forKey: .value))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(value, forKey: .value)
  }

  enum CodingKeys: String, CodingKey {
    case id, value
  }
}

// MARK: - MessageRole + Decodable

extension MessageRole: Decodable { }

// MARK: - ChatEventModel + Codable

extension ChatEventModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "message":
      let data = try container.decode(ChatMessageContentWithRoleModel.self, forKey: .data)
      self = .message(data)

    case "checkpoint":
      let data = try container.decode(Checkpoint.self, forKey: .data)
      self = .checkpoint(data)

    default:
      throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type: \(type)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .message(let data):
      try container.encode("message", forKey: .type)
      try container.encode(data, forKey: .data)

    case .checkpoint(let data):
      try container.encode("checkpoint", forKey: .type)
      try container.encode(data, forKey: .data)
    }
  }

  enum CodingKeys: String, CodingKey {
    case type
    case data
  }

}

// MARK: - Checkpoint + Codable

extension Checkpoint: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(String.self, forKey: .id),
      message: container.decode(String.self, forKey: .message),
      projectRoot: container.decode(URL.self, forKey: .projectRoot),
      taskId: container.decode(String.self, forKey: .taskId))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(message, forKey: .message)
    try container.encode(projectRoot, forKey: .projectRoot)
    try container.encode(taskId, forKey: .taskId)
  }

  enum CodingKeys: String, CodingKey {
    case id, message, projectRoot, taskId
  }
}

// MARK: - AttachmentModel + Codable

extension AttachmentModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "file":
      let data = try container.decode(FileAttachmentModel.self, forKey: .data)
      self = .file(data)

    case "image":
      let data = try container.decode(ImageAttachmentModel.self, forKey: .data)
      self = .image(data)

    case "fileSelection":
      let data = try container.decode(FileSelectionAttachmentModel.self, forKey: .data)
      self = .fileSelection(data)

    case "buildError":
      let data = try container.decode(BuildErrorModel.self, forKey: .data)
      self = .buildError(data)

    default:
      throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown attachment type: \(type)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .file(let data):
      try container.encode("file", forKey: .type)
      try container.encode(data, forKey: .data)

    case .image(let data):
      try container.encode("image", forKey: .type)
      try container.encode(data, forKey: .data)

    case .fileSelection(let data):
      try container.encode("fileSelection", forKey: .type)
      try container.encode(data, forKey: .data)

    case .buildError(let data):
      try container.encode("buildError", forKey: .type)
      try container.encode(data, forKey: .data)
    }
  }

  enum CodingKeys: String, CodingKey {
    case type, data
  }
}

// MARK: - AttachmentModel.FileAttachmentModel + Codable

extension AttachmentModel.FileAttachmentModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let attachmentSerializer = try decoder.attachmentSerializer
    let id = try container.decode(UUID.self, forKey: .id)
    try self.init(
      id: id,
      path: container.decode(URL.self, forKey: .path),
      content: attachmentSerializer.read(String.self, for: id))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let attachmentSerializer = try encoder.attachmentSerializer
    try container.encode(id, forKey: .id)
    try container.encode(path, forKey: .path)
    try attachmentSerializer.save(content, for: id)
  }

  enum CodingKeys: String, CodingKey {
    case id, path, content
  }
}

// MARK: - AttachmentModel.ImageAttachmentModel + Codable

extension AttachmentModel.ImageAttachmentModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let attachmentSerializer = try decoder.attachmentSerializer
    let id = try container.decode(UUID.self, forKey: .id)
    try self.init(
      id: id,
      imageData: attachmentSerializer.read(Data.self, for: id),
      path: container.decodeIfPresent(URL.self, forKey: .path))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let attachmentSerializer = try encoder.attachmentSerializer
    try container.encode(id, forKey: .id)
    try container.encode(imageData, forKey: .imageData)
    try attachmentSerializer.save(imageData, for: id)
  }

  enum CodingKeys: String, CodingKey {
    case id, imageData, path
  }
}

// MARK: - AttachmentModel.FileSelectionAttachmentModel + Codable

extension AttachmentModel.FileSelectionAttachmentModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      file: container.decode(AttachmentModel.FileAttachmentModel.self, forKey: .file),
      startLine: container.decode(Int.self, forKey: .startLine),
      endLine: container.decode(Int.self, forKey: .endLine))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(file, forKey: .file)
    try container.encode(startLine, forKey: .startLine)
    try container.encode(endLine, forKey: .endLine)
  }

  enum CodingKeys: String, CodingKey {
    case id, file, startLine, endLine
  }
}

// MARK: - AttachmentModel.BuildErrorModel + Codable

extension AttachmentModel.BuildErrorModel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      message: container.decode(String.self, forKey: .message),
      filePath: container.decode(URL.self, forKey: .filePath),
      line: container.decode(Int.self, forKey: .line),
      column: container.decode(Int.self, forKey: .column))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(message, forKey: .message)
    try container.encode(filePath, forKey: .filePath)
    try container.encode(line, forKey: .line)
    try container.encode(column, forKey: .column)
  }

  enum CodingKeys: String, CodingKey {
    case id, message, filePath, line, column
  }
}
