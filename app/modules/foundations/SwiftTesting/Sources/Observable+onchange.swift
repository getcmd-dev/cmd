// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import Observation
import Testing

extension Observable where Self: Sendable {

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
