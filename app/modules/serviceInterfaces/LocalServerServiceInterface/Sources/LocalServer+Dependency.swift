// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - LocalServerDependencyKey

public final class LocalServerDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: LocalServer = MockLocalServer()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: LocalServer = () as! LocalServer
  #endif
}

extension DependencyValues {
  public var localServer: LocalServer {
    get { self[LocalServerDependencyKey.self] }
    set { self[LocalServerDependencyKey.self] = newValue }
  }
}
