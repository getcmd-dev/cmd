// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Foundation
import Observation
import Testing

extension Observable where Self: Sendable {
  /// When the value of a at a given key path changes, this function will be called.
  public func didSet<Value: Sendable>(
    _ keyPath: KeyPath<Self, Value>,
    perform action: @Sendable @escaping (Value) -> Void)
    -> Cancellable
  {
    let cancellable = AnyCancellable { }
    withObservationTracking(
      {
        _ = self[keyPath: keyPath]
      },
      token: { [weak cancellable] in
        guard let cancellable else { return nil }
        _ = cancellable
        return ""
      },
      willChange: nil,
      didChange: {
        action(self[keyPath: keyPath])
      })
    return cancellable
  }

  /// Wait for the property at the given key path to change to the desired value.
  public func wait<Value: Sendable & Equatable>(
    for keyPath: KeyPath<Self, Value>,
    toBe desiredValue: Value,
    timeout: TimeInterval = 5,
    _sourceLocation: SourceLocation = #_sourceLocation)
    async throws
  {
    let exp = expectation(
      description: "The property at \(keyPath.debugDescription) changed to the desired value",
      _sourceLocation: _sourceLocation)
    let cancellable = didSet(keyPath) { value in
      if value == desiredValue {
        exp.fulfillAtMostOnce()
      }
    }
    if self[keyPath: keyPath] == desiredValue {
      exp.fulfillAtMostOnce()
    }
    try await fulfillment(of: exp, timeout: timeout)
    _ = cancellable
  }
}

// extension KeyPath: @retroactive @unchecked Sendable { }

func withObservationTracking(
  _ apply: @Sendable @escaping () -> Void,
  token: @Sendable @escaping () -> String?,
  willChange: (@Sendable () -> Void)? = nil,
  didChange: @escaping @Sendable () -> Void)
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
        didChange: didChange)
    }
  }
}
