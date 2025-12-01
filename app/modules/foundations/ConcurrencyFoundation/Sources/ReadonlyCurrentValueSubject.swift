// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Foundation
import os

// MARK: - ReadonlyCurrentValueSubject

/// `ReadonlyCurrentValueSubject` is a readonly version of `CurrentValueSubject`.
/// It can be used to represent a value that can be observed but not modified directly.
public final class ReadonlyCurrentValueSubject<Output: Sendable>: Publisher, Sendable {
  public init(_ value: Output, publisher: AnyPublisher<Output, Never>) {
    _value = Atomic(value)
    self.publisher = publisher
    let cancellable = publisher.sink { [weak self] newValue in
      self?._value.set(to: newValue)
    }
    subscription.set(to: cancellable)
  }

  public convenience init(_ value: CurrentValueSubject<Output, Never>) {
    self.init(value.value, publisher: value.eraseToAnyPublisher())
  }

  public typealias Failure = Never

  public var value: Output {
    _value.value
  }

  public static func just(_ value: Output) -> Self {
    .init(value, publisher: CurrentValueSubject(value).eraseToAnyPublisher())
  }

  public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, S.Input == Output {
    publisher.receive(subscriber: subscriber)
  }

  private let _value: Atomic<Output>
  private let subscription = Atomic(nil as AnyCancellable?)
  private let publisher: AnyPublisher<Output, Never>

}

extension CurrentValueSubject where Output: Sendable, Failure == Never {
  public func readonly() -> ReadonlyCurrentValueSubject<Output> {
    ReadonlyCurrentValueSubject(value, publisher: eraseToAnyPublisher())
  }
}

extension CurrentValueSubject where Output: Sendable & Equatable, Failure == Never {
  public func readonly(removingDuplicate: Bool) -> ReadonlyCurrentValueSubject<Output> {
    if removingDuplicate {
      ReadonlyCurrentValueSubject(value, publisher: removeDuplicates().eraseToAnyPublisher())
    } else {
      readonly()
    }
  }
}
