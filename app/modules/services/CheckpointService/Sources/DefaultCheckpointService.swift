// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CheckpointServiceInterface
import DependencyFoundation
import Foundation
import JSONFoundation
import LocalServerServiceInterface

// MARK: - DefaultCheckpointService

final class DefaultCheckpointService: CheckpointService {

  // MARK: - Initialization

  init(server: LocalServer) {
    self.server = server
  }

  // MARK: - CheckpointService

  func createCheckpoint(projectRoot: URL, taskId: String, message: String) async throws -> Checkpoint {
    let requestParams = Schema.CreateCheckpointRequestParams(
      projectRoot: projectRoot.path(),
      taskId: taskId,
      message: message)

    let requestData = try JSONEncoder().encode(requestParams)
    let response: Schema.CreateCheckpointResponseParams = try await server.postRequest(
      path: "checkpoint/create",
      data: requestData)
    return Checkpoint(id: response.commitSha, message: message, projectRoot: projectRoot, taskId: taskId)
  }

  func restore(checkpoint: Checkpoint) async throws {
    let requestParams = Schema.RestoreCheckpointRequestParams(
      projectRoot: checkpoint.projectRoot.path,
      taskId: checkpoint.taskId,
      commitSha: checkpoint.id)

    let requestData = try JSONEncoder().encode(requestParams)
    let _: Schema.RestoreCheckpointResponseParams = try await server.postRequest(
      path: "checkpoint/restore",
      data: requestData)
  }

  private let server: LocalServer
}

// MARK: - Dependency Injection

extension BaseProviding where Self: LocalServerProviding {
  public var checkpointService: CheckpointService {
    shared {
      DefaultCheckpointService(server: localServer)
    }
  }
}
