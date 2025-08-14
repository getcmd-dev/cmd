// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/checkpointSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct CreateCheckpointRequestParams: Codable, Sendable {
    public let projectRoot: String
    public let taskId: String
    public let message: String
  
    private enum CodingKeys: String, CodingKey {
      case projectRoot = "projectRoot"
      case taskId = "taskId"
      case message = "message"
    }
  
    public init(
        projectRoot: String,
        taskId: String,
        message: String
    ) {
      self.projectRoot = projectRoot
      self.taskId = taskId
      self.message = message
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      projectRoot = try container.decode(String.self, forKey: .projectRoot)
      taskId = try container.decode(String.self, forKey: .taskId)
      message = try container.decode(String.self, forKey: .message)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(projectRoot, forKey: .projectRoot)
      try container.encode(taskId, forKey: .taskId)
      try container.encode(message, forKey: .message)
    }
  }
  public struct CreateCheckpointResponseParams: Codable, Sendable {
    public let commitSha: String
  
    private enum CodingKeys: String, CodingKey {
      case commitSha = "commitSha"
    }
  
    public init(
        commitSha: String
    ) {
      self.commitSha = commitSha
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      commitSha = try container.decode(String.self, forKey: .commitSha)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(commitSha, forKey: .commitSha)
    }
  }
  public struct RestoreCheckpointRequestParams: Codable, Sendable {
    public let projectRoot: String
    public let taskId: String
    public let commitSha: String
  
    private enum CodingKeys: String, CodingKey {
      case projectRoot = "projectRoot"
      case taskId = "taskId"
      case commitSha = "commitSha"
    }
  
    public init(
        projectRoot: String,
        taskId: String,
        commitSha: String
    ) {
      self.projectRoot = projectRoot
      self.taskId = taskId
      self.commitSha = commitSha
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      projectRoot = try container.decode(String.self, forKey: .projectRoot)
      taskId = try container.decode(String.self, forKey: .taskId)
      commitSha = try container.decode(String.self, forKey: .commitSha)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(projectRoot, forKey: .projectRoot)
      try container.encode(taskId, forKey: .taskId)
      try container.encode(commitSha, forKey: .commitSha)
    }
  }
  public struct RestoreCheckpointResponseParams: Codable, Sendable {
    public let commitSha: String
  
    private enum CodingKeys: String, CodingKey {
      case commitSha = "commitSha"
    }
  
    public init(
        commitSha: String
    ) {
      self.commitSha = commitSha
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      commitSha = try container.decode(String.self, forKey: .commitSha)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(commitSha, forKey: .commitSha)
    }
  }}
