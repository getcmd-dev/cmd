// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@_exported import ConcurrencyFoundation
import Dependencies

// MARK: - AppsActivationStateDependencyKey

public final class AppsActivationStateDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: ReadonlyCurrentValueSubject<AppsActivationState> = AppsActivationState.mockPublisher()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: ReadonlyCurrentValueSubject<AppsActivationState> = () as! ReadonlyCurrentValueSubject<
    AppsActivationState,
    Never,
  >
  #endif
}

extension DependencyValues {
  public var appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState> {
    get { self[AppsActivationStateDependencyKey.self] }
    set { self[AppsActivationStateDependencyKey.self] = newValue }
  }
}
