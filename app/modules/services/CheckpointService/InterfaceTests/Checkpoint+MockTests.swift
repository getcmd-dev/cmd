// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation
import SwiftTesting
import Testing
@testable import CheckpointServiceInterface

struct MockCheckpointServiceTests {

  // MARK: - Create Checkpoint Tests

  @Test
  func testCreateCheckpointSuccess() async throws {
    let service = MockCheckpointService()
    let expectedSha = "abcdef1234567890"

    service.onCreateCheckpoint = { projectRoot, taskId, message in
      #expect(projectRoot.path == "/test/project")
      #expect(taskId == "task-123")
      #expect(message == "Test checkpoint")
      return Checkpoint(id: expectedSha, message: message, projectRoot: projectRoot, taskId: taskId)
    }

    let result = try await service.createCheckpoint(
      projectRoot: URL(filePath: "/test/project"),
      taskId: "task-123",
      message: "Test checkpoint")

    #expect(result.id == expectedSha)
  }

  @Test
  func testCreateCheckpointFailure() async throws {
    let service = MockCheckpointService()
    let expectedError = AppError("Failed to create checkpoint")

    service.onCreateCheckpoint = { _, _, _ in
      throw expectedError
    }

    do {
      _ = try await service.createCheckpoint(
        projectRoot: URL(filePath: "/test/project"),
        taskId: "task-123",
        message: "Test checkpoint")
      Issue.record("Expected error to be thrown")
    } catch let error as AppError {
      #expect(error.localizedDescription == expectedError.localizedDescription)
    }
  }

  // MARK: - Restore Checkpoint Tests

  @Test
  func testRestoreCheckpointSuccess() async throws {
    let service = MockCheckpointService()
    let expectation = expectation(description: "Restore checkpoint called")

    service.onRestoreCheckpoint = { checkpoint in
      #expect(checkpoint.projectRoot.path == "/test/project")
      #expect(checkpoint.taskId == "task-123")
      #expect(checkpoint.id == "abcdef1234567890")
      expectation.fulfill()
    }

    try await service.restore(checkpoint: Checkpoint(
      id: "abcdef1234567890",
      message: "checkpoint",
      projectRoot: URL(filePath: "/test/project"),
      taskId: "task-123"))

    try await fulfillment(of: expectation)
  }

  @Test
  func testRestoreCheckpointFailure() async throws {
    let service = MockCheckpointService()
    let expectedError = AppError("Failed to restore checkpoint")

    service.onRestoreCheckpoint = { _ in
      throw expectedError
    }

    do {
      try await service.restore(checkpoint: Checkpoint(
        id: "abcdef1234567890",
        message: "checkpoint",
        projectRoot: URL(filePath: "/test/project"),
        taskId: "task-123"))
      Issue.record("Expected error to be thrown")
    } catch let error as AppError {
      #expect(error.localizedDescription == expectedError.localizedDescription)
    }
  }
}
