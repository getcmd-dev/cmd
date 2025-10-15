// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Dependencies

// MARK: - AppsActivationStateDependencyKey

public final class AppsActivationStateDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: AnyPublisher<AppsActivationState, Never> = AppsActivationState.mockPublisher()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: AnyPublisher<AppsActivationState, Never> = Just(AppsActivationState.inactive).eraseToAnyPublisher()
  #endif
}

extension DependencyValues {
  public var appsActivationState: AnyPublisher<AppsActivationState, Never> {
    get { self[AppsActivationStateDependencyKey.self] }
    set { self[AppsActivationStateDependencyKey.self] = newValue }
  }
}
