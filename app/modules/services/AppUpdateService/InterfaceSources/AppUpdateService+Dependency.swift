// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - AppUpdateServiceDependencyKey

public final class AppUpdateServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: AppUpdateService = MockAppUpdateService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: AppUpdateService = () as! AppUpdateService
  #endif
}

extension DependencyValues {
  public var appUpdateService: AppUpdateService {
    get { self[AppUpdateServiceDependencyKey.self] }
    set { self[AppUpdateServiceDependencyKey.self] = newValue }
  }
}
