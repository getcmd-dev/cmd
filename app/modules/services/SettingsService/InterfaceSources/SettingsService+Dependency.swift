// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - SettingsServiceDependencyKey

public final class SettingsServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: SettingsService = MockSettingsService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: SettingsService = () as! SettingsService
  #endif
}

extension DependencyValues {
  public var settingsService: SettingsService {
    get { self[SettingsServiceDependencyKey.self] }
    set { self[SettingsServiceDependencyKey.self] = newValue }
  }
}
