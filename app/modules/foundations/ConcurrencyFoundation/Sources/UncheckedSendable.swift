// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// MARK: - UncheckedSendable

/// A  wrapper that conforms to `Sendable`. This is particularly useful over `@unchecked Sendable` for types such
/// as closures that cannot be annotated with `@unchecked`.
public final class UncheckedSendable<Value>: @unchecked Sendable {

  public init(_ value: Value) {
    wrapped = value
  }

  public let wrapped: Value

}
