// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - CheckpointServiceDependencyKey

public final class CheckpointServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: CheckpointService = MockCheckpointService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: CheckpointService = () as! CheckpointService
  #endif
}

extension DependencyValues {
  public var checkpointService: CheckpointService {
    get { self[CheckpointServiceDependencyKey.self] }
    set { self[CheckpointServiceDependencyKey.self] = newValue }
  }
}
