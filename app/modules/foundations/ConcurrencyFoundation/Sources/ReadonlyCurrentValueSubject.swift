// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Foundation
import os

// MARK: - ReadonlyCurrentValueSubject

/// `ReadonlyCurrentValueSubject` is a readonly version of `CurrentValueSubject`.
/// It can be used to represent a value that can be observed but not modified directly.
public final class ReadonlyCurrentValueSubject<Output: Sendable, Failure: Error>: Publisher, Sendable {

  public init(_ value: Output, publisher: AnyPublisher<Output, Failure>) {
    self.value = Atomic(value)
    self.publisher = publisher
  }

  public convenience init(_ value: CurrentValueSubject<Output, Failure>) {
    self.init(value.value, publisher: value.eraseToAnyPublisher())
  }

  public var currentValue: Output {
    value.value
  }

  public static func just(_ value: Output) -> Self {
    .init(value, publisher: CurrentValueSubject(value).eraseToAnyPublisher())
  }

  public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, S.Input == Output {
    publisher.receive(subscriber: subscriber)
  }

  private let value: Atomic<Output>
  private let publisher: AnyPublisher<Output, Failure>

}

extension CurrentValueSubject where Output: Sendable {
  public func readonly() -> ReadonlyCurrentValueSubject<Output, Failure> {
    ReadonlyCurrentValueSubject(value, publisher: eraseToAnyPublisher())
  }
}

extension CurrentValueSubject where Output: Sendable & Equatable {
  public func readonly(removingDuplicate: Bool) -> ReadonlyCurrentValueSubject<Output, Failure> {
    if removingDuplicate {
      ReadonlyCurrentValueSubject(value, publisher: removeDuplicates().eraseToAnyPublisher())
    } else {
      readonly()
    }
  }
}
