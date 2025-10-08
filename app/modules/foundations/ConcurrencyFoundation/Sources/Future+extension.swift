// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Foundation

extension Future {

  /// Similar to `init(_:)`, but the closure is allowed to be `@Sendable`.
  public convenience init(_ sendableAttemptToFulfill: @escaping (@Sendable @escaping (Result<Output, Failure>) -> Void) -> Void) {
    self.init { attemptToFulfill in
      let uncheckedSendable = UncheckedSendable(attemptToFulfill)
      sendableAttemptToFulfill { result in
        uncheckedSendable.wrapped(result)
      }
    }
  }

  /// Return a Future and continuation handler.
  /// The future is resolved when the handler is called.
  /// The handler should be called exactly once otherwise the app will crash.
  public static func make() -> (Future<Output, Failure>, @Sendable (Result<Output, Failure>) -> Void) {
    var promise: (Result<Output, Failure>) -> Void = { _ in }
    let future = Future { p in
      promise = p
    }

    let uncheckedSendable = UncheckedSendable(promise)
    let completion: @Sendable (Result<Output, Failure>) -> Void = { result in
      uncheckedSendable.wrapped(result)
    }
    return (future, completion)
  }

  /// Return a Future and continuation handler.
  /// The future is resolved when the handler is called for the first time.
  /// The handler can be called several times without crashing the app. Only the first call will have an effect.
  public static func makeRacingContinuations() -> (Future<Output, Failure>, RacedContinuation<Output, Failure>) {
    let hasContinued = Atomic(false)
    var promise: (Result<Output, Failure>) -> Void = { _ in }
    let future = Future { p in
      promise = p
    }

    let uncheckedSendable = UncheckedSendable(promise)
    let continuation = RacedContinuation<Output, Failure>() { result in
      let hadContinued = hasContinued.set(to: true)
      if !hadContinued {
        // Only continue once.
        uncheckedSendable.wrapped(result)
      }
    }
    return (future, continuation)
  }

  public static func Just(_ output: Output) -> Future<Output, Failure> {
    Future { $0(.success(output)) }
  }
}

public func withRacedThrowingContinuation<T>(_ body: (RacedContinuation<T, any Error>) -> Void) async throws -> T {
  let (future, continuation) = Future<T, any Error>.makeRacingContinuations()
  body(continuation)
  return try await future.value
}

public func withRacedContinuation<T>(_ body: (RacedContinuation<T, Never>) -> Void) async throws -> T {
  let (future, continuation) = Future<T, Never>.makeRacingContinuations()
  body(continuation)
  return await future.value
}

// MARK: - RacedContinuation

public struct RacedContinuation<T, E>: Sendable where E: Error {

  init(_ handler: @Sendable @escaping (Result<T, E>) -> Void) {
    self.handler = handler
  }

  /// Resume the task awaiting the continuation by having it return normally
  /// from its suspension point.
  ///
  /// - Parameter value: The value to return from the continuation.
  ///
  /// A continuation must be resumed exactly once. If the continuation has
  /// already been resumed through this object, then the attempt to resume
  /// the continuation will trap.
  ///
  /// After `resume` enqueues the task, control immediately returns to
  /// the caller. The task continues executing when its executor is
  /// able to reschedule it.
  public func resume(returning value: T) {
    handler(.success(value))
  }

  /// Resume the task awaiting the continuation by having it throw an error
  /// from its suspension point.
  ///
  /// - Parameter error: The error to throw from the continuation.
  ///
  /// A continuation must be resumed exactly once. If the continuation has
  /// already been resumed through this object, then the attempt to resume
  /// the continuation will trap.
  ///
  /// After `resume` enqueues the task, control immediately returns to
  /// the caller. The task continues executing when its executor is
  /// able to reschedule it.
  public func resume(throwing error: E) {
    handler(.failure(error))
  }

  private let handler: @Sendable (Result<T, E>) -> Void

}

extension RacedContinuation {
  public func resume(_ result: Result<T, E>) {
    switch result {
    case .success(let value):
      resume(returning: value)
    case .failure(let error):
      resume(throwing: error)
    }
  }
}

extension RacedContinuation where T == Void {
  public func resume() {
    resume(returning: ())
  }
}

extension RacedContinuation where E == Error {
  public func timeout(afterNanoseconds nanoseconds: UInt64) {
    Task {
      try await Task.sleep(nanoseconds: nanoseconds)
      resume(throwing: TimeoutError())
    }
  }
}

// MARK: - TimeoutError

public struct TimeoutError: Error, LocalizedError {
  public var errorDescription: String? { "The operation has timed out." }
}
