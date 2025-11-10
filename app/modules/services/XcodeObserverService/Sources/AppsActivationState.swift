// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import DependencyFoundation
import XcodeObserverServiceInterface

extension BaseProviding where Self: IsHostAppActiveProviding, Self: XcodeObserverProviding {
  public var appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState> {
    shared {
      let publisher: AnyPublisher<AppsActivationState, Never> = xcodeObserver.statePublisher
        .compactMap {
          $0.activeInstance != nil
        }
        .combineLatest(isHostAppActive)
        .map { isXcodeActive, isHostAppActive in
          if isXcodeActive, isHostAppActive {
            .bothActive
          } else if isXcodeActive {
            .xcodeActive
          } else if isHostAppActive {
            .hostAppActive
          } else {
            .inactive
          }
        }
        .removeDuplicates()
        .eraseToAnyPublisher()

      return .init(.inactive, publisher: publisher)
    }
  }
}
