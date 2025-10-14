// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - PermissionsServiceDependencyKey

public final class PermissionsServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: PermissionsService = MockPermissionsService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: PermissionsService = () as! PermissionsService
  #endif
}

extension DependencyValues {
  public var permissionsService: PermissionsService {
    get { self[PermissionsServiceDependencyKey.self] }
    set { self[PermissionsServiceDependencyKey.self] = newValue }
  }
}
