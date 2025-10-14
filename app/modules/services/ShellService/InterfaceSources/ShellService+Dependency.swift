// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - ShellServiceDependencyKey

public final class ShellServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: ShellService = MockShellService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: ShellService = () as! ShellService
  #endif
}

extension DependencyValues {
  public var shellService: ShellService {
    get { self[ShellServiceDependencyKey.self] }
    set { self[ShellServiceDependencyKey.self] = newValue }
  }
}
