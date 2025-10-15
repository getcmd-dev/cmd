// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation

#if DEBUG
public final class MockCheckpointService: CheckpointService {
  public init() { }

  public var onCreateCheckpoint: @Sendable (_ projectRoot: URL, _ taskId: String, _ message: String) async throws -> Checkpoint {
    get { _onCreateCheckpoint.value }
    set { _onCreateCheckpoint.mutate { $0 = newValue } }
  }

  public var onRestoreCheckpoint: @Sendable (_ checkpoint: Checkpoint) async throws -> Void {
    get { _onRestoreCheckpoint.value }
    set { _onRestoreCheckpoint.mutate { $0 = newValue } }
  }

  public func createCheckpoint(projectRoot: URL, taskId: String, message: String) async throws -> Checkpoint {
    try await onCreateCheckpoint(projectRoot, taskId, message)
  }

  public func restore(checkpoint: Checkpoint) async throws {
    try await onRestoreCheckpoint(checkpoint)
  }

  private let _onCreateCheckpoint =
    Atomic<@Sendable (_ projectRoot: URL, _ taskId: String, _ message: String) async throws -> Checkpoint> { _, _, _ in
      throw AppError("Not implemented")
    }

  private let _onRestoreCheckpoint =
    Atomic<@Sendable (_ checkpoint: Checkpoint) async throws -> Void> { _ in
      throw AppError("Not implemented")
    }
}
#endif
