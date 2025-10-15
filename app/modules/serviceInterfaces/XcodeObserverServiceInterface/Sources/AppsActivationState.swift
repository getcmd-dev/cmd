// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import Combine

// MARK: - AppsActivationState

/// The activation state of the Xcode and host app.
///
/// As the host app is behaving as part of Xcode, it can be useful to know display it as an active app if Xcode is active,
/// or to display Xcode as active if the host app is active.
public enum AppsActivationState: Equatable, Sendable {
  case bothActive
  case xcodeActive
  case hostAppActive
  case inactive
}

extension AppsActivationState {
  public var isXcodeActive: Bool {
    if case .bothActive = self { return true }
    if case .xcodeActive = self { return true }
    return false
  }

  public var isHostAppActive: Bool {
    if case .bothActive = self { return true }
    if case .hostAppActive = self { return true }
    return false
  }

  public var isEitherXcodeOrHostAppActive: Bool {
    isXcodeActive || isHostAppActive
  }
}

// MARK: - AppsActivationStateProviding

public protocol AppsActivationStateProviding {
  var appsActivationState: AnyPublisher<AppsActivationState, Never> { get }
}
