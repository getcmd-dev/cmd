// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - AppEventHandlerRegistryDependencyKey

public final class AppEventHandlerRegistryDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: AppEventHandlerRegistry = MockAppEventHandlerRegistry()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: AppEventHandlerRegistry = () as! AppEventHandlerRegistry
  #endif
}

extension DependencyValues {
  public var appEventHandlerRegistry: AppEventHandlerRegistry {
    get { self[AppEventHandlerRegistryDependencyKey.self] }
    set { self[AppEventHandlerRegistryDependencyKey.self] = newValue }
  }
}
