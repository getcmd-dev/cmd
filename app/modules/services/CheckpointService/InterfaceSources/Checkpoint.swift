// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

// MARK: - CheckpointService

public protocol CheckpointService: Sendable {
  /// Creates a checkpoint for the given project and task
  /// - Parameters:
  ///   - projectRoot: The root directory of the project
  ///   - taskId: The task identifier
  ///   - message: A message describing the checkpoint
  /// - Returns: The commit SHA for the created checkpoint
  func createCheckpoint(projectRoot: URL, taskId: String, message: String) async throws -> Checkpoint

  /// Restores a project to a specific checkpoint
  /// - Parameters:
  ///   - projectRoot: The root directory of the project
  ///   - taskId: The task identifier
  ///   - commitSha: The SHA of the commit to restore to
  func restore(checkpoint: Checkpoint) async throws
}

// MARK: - Checkpoint

public struct Checkpoint: Sendable {
  public let id: String
  public let message: String
  public let projectRoot: URL
  public let taskId: String

  public init(
    id: String,
    message: String,
    projectRoot: URL,
    taskId: String)
  {
    self.id = id
    self.message = message
    self.projectRoot = projectRoot
    self.taskId = taskId
  }
}

// MARK: - CheckpointServiceProviding

public protocol CheckpointServiceProviding {
  var checkpointService: CheckpointService { get }
}
