// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - XcodeControllerDependencyKey

public final class XcodeControllerDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: XcodeController = MockXcodeController()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: XcodeController = () as! XcodeController
  #endif
}

extension DependencyValues {
  public var xcodeController: XcodeController {
    get { self[XcodeControllerDependencyKey.self] }
    set { self[XcodeControllerDependencyKey.self] = newValue }
  }
}
