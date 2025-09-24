// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Foundation
import Observation

extension Observable where Self: Sendable {
  /// When the value of a given key path changes, this function will be called once.
  public func didSet<Value: Sendable>(
    _ keyPath: KeyPath<Self, Value>,
    perform action: @Sendable @escaping (Value) -> Void)
    -> AnyCancellable
  {
    let isCancelled = Atomic(false)
    let cancellable = AnyCancellable {
      isCancelled.set(to: true)
    }
    withObservationTracking(
      {
        _ = self[keyPath: keyPath]
      },
      token: {
        guard !isCancelled.value else {
          return nil
        }
        return ""
      },
      willChange: nil,
      didChange: { [weak cancellable] in
        action(self[keyPath: keyPath])
        cancellable?.cancel()
      })
    return cancellable
  }

  public func observeChanges<Value: Sendable>(to keyPath: KeyPath<Self, Value>) -> AnyPublisher<Value, Never> {
    ObservablePublisher(observable: self, computedValue: { $0[keyPath: keyPath] }).eraseToAnyPublisher()
  }

  public func observeChanges<Value: Sendable>(of computedValue: @Sendable @escaping (Self) -> Value)
    -> AnyPublisher<Value, Never>
  {
    ObservablePublisher(observable: self, computedValue: computedValue).eraseToAnyPublisher()
  }

  /// Get notified each time the value of a given key path changes, until cancelled.
  public func observeChanges<Value: Sendable>(
    to keyPath: KeyPath<Self, Value>,
    perform action: @Sendable @escaping (Value) -> Void)
    -> AnyCancellable
  {
    observeChanges(of: { $0[keyPath: keyPath] }, perform: action)
  }

  /// Get notified each time the value of a given key path changes, until cancelled.
  public func observeChanges<Value: Sendable>(
    of computedValue: @Sendable @escaping (Self) -> Value,
    perform action: @Sendable @escaping (Value) -> Void)
    -> AnyCancellable
  {
    let isFirstObservation = Atomic<Bool>(true)

    let isCancelled = Atomic(false)
    let cancellable = AnyCancellable {
      isCancelled.set(to: true)
    }

    withObservationTracking(
      {
        let value = computedValue(self)
        let wasFirstObservation = isFirstObservation.set(to: false)
        if !wasFirstObservation {
          action(value)
        }
      },
      token: {
        guard !isCancelled.value else {
          return nil
        }
        return ""
      },
      willChange: nil,
      didChange: {
        // apply will be called immediately after.
      })
    return cancellable
  }
}

func withObservationTracking(
  _ apply: @Sendable @escaping () -> Void,
  token: @Sendable @escaping () -> String?,
  willChange: (@Sendable () -> Void)? = nil,
  didChange: @escaping @Sendable () -> Void,
  counter: Int = 0)
{
  withObservationTracking(apply) {
    guard token() != nil else { return }
    willChange?()
    RunLoop.current.perform {
      didChange()
      withObservationTracking(
        apply,
        token: token,
        willChange: willChange,
        didChange: didChange,
        counter: counter + 1)
    }
  }
}

// MARK: - ObservablePublisher

public final class ObservablePublisher<Object: Observable, Output>: Publisher, Sendable {
  init(observable: Object, computedValue: @Sendable @escaping (Object) -> Output) {
    let internalPublisher = PassthroughSubject<Output, Never>()
    self.internalPublisher = internalPublisher
    cancellable = observable.observeChanges(of: computedValue) { newValue in
      internalPublisher.send(newValue)
    }
  }

  public typealias Failure = Never

  public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
    let subscription = RetainingPublisherSubscription(
      retained: self,
      publisher: internalPublisher,
      subscriber: subscriber)
    subscriber.receive(subscription: subscription)
  }

  private let internalPublisher: PassthroughSubject<Output, Never>

  private let cancellable: AnyCancellable

}
