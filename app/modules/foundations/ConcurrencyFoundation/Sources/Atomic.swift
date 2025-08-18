// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import os

// MARK: - Atomic

@dynamicMemberLookup
public final class Atomic<Value: Sendable>: Sendable {

  public init(_ value: Value) {
    lock = .init(initialState: value)
  }

  public var value: Value {
    lock.withLock { $0 }
  }

  @discardableResult
  public func mutate<Result: Sendable>(_ mutation: @Sendable (inout Value) throws -> Result) rethrows -> Result {
    try lock.withLock { try mutation(&$0) }
  }

  /// Set to the new value and return the old value.
  @discardableResult
  public func set(to newValue: Value) -> Value {
    lock.withLock { value in
      let oldValue = value
      value = newValue
      return oldValue
    }
  }

  /// Set to property to the new value and return the old value.
  @discardableResult
  public func set<T: Sendable>(_ keyPath: WritableKeyPath<Value, T>, to newValue: T) -> T {
    lock.withLock { value in
      let oldValue = value[keyPath: keyPath]
      value[keyPath: keyPath] = newValue
      return oldValue
    }
  }

  public subscript<T: Sendable>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> T {
    get { value[keyPath: keyPath] }
    set { lock.withLock { value in value[keyPath: keyPath] = newValue } }
  }

  public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
    value[keyPath: keyPath]
  }

  private let lock: OSAllocatedUnfairLock<Value>

}

// MARK: - KeyPath + @unchecked @retroactive Sendable

extension KeyPath: @unchecked @retroactive Sendable where Root: Sendable, Value: Sendable { }

extension Atomic where Value == Int {
  @discardableResult
  public func increment() -> Int {
    mutate {
      $0 += 1
      return $0
    }
  }
}
