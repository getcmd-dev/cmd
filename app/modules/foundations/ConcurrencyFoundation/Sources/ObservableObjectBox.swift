// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Foundation
import os

// MARK: - ObservableObjectBox

/// `ObservableObjectBox` wraps a value in an object that conforms to `ObservableObject`.
/// Updates are done in the main thread, asynchronously from the upstream source if this one is not running on the main thread, synchronously otherwise.
public final class ObservableObjectBox<Value: Sendable>: ObservableObject, @unchecked Sendable {
  @MainActor
  public init(from value: ReadonlyCurrentValueSubject<Value, Never>) {
    wrappedValue = value.currentValue

    cancellable = value.sink { @Sendable [weak self] newValue in
      runOnMainThread {
        guard let self else { return }
        self.wrappedValue = newValue
      }
    }
  }

  @MainActor
  public init(_ value: Value) {
    wrappedValue = value
  }

  @Published @MainActor public var wrappedValue: Value

  private var cancellable: AnyCancellable?

}

extension ReadonlyCurrentValueSubject where Failure == Never {
  @MainActor
  public func asObservableObjectBox() -> ObservableObjectBox<Output> {
    ObservableObjectBox(from: self)
  }
}

extension ObservableObjectBox {
  @MainActor
  public func map<T: Sendable>(_ transform: @escaping (Value) -> T) -> ObservableObjectBox<T> {
    .init(from: .init(transform(wrappedValue), publisher: $wrappedValue.map(transform).eraseToAnyPublisher()))
  }
}
