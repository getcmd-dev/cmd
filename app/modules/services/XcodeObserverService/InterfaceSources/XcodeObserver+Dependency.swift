// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - XcodeObserverDependencyKey

public final class XcodeObserverDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: XcodeObserver = MockXcodeObserver(.unknown)
  #else
  /// This is not read outside of DEBUG
  public static let testValue: XcodeObserver = () as! XcodeObserver
  #endif
}

extension DependencyValues {
  public var xcodeObserver: XcodeObserver {
    get { self[XcodeObserverDependencyKey.self] }
    set { self[XcodeObserverDependencyKey.self] = newValue }
  }
}
