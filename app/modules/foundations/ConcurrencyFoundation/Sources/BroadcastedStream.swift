// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Foundation
import os

// MARK: - BroadcastedStream

/// Like AsyncStream, but can be observed by multiple subscribers, concurrently or not.
public final class BroadcastedStream<Element: Sendable>: AsyncSequence, Sendable {

  public convenience init(_: Element.Type = Element.self, _ build: (Continuation) -> Void) {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    self.init(internalStream: stream)

    build(continuation)
  }

  /// Initialize with a publisher that emits updates.
  public convenience init(_ publisher: AnyPublisher<Element, Never>, _ finish: (@escaping () -> Void) -> Void) {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    self.init(internalStream: stream)

    let cancellable = publisher.sink { element in
      continuation.yield(element)
    }
    cancellables.mutate { $0.insert(cancellable) }

    finish { continuation.finish() }
  }

  /// Initialize with a stream that emits updates, and signal when the updates are done.
  public convenience init(_ stream: AsyncStream<Element>) {
    self.init(internalStream: stream)
  }

  private init(internalStream: AsyncStream<Element>) {
    self.internalStream = internalStream

    Task { [weak self] in
      for await element in internalStream {
          if self == nil {
             os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "UnknownApp", category: "command")
                  .warning("The BroadcastedStream received an event after being deallocated. It will not be forwarded to its subscribers.")
          }
        self?.broadcast(element)
      }
      self?.finish()
    }
  }

  public typealias AsyncIterator = AsyncStream<Element>.Iterator
  public typealias Failure = Never
  public typealias Continuation = AsyncStream<Element>.Continuation

  /// A stream of updates.
  /// It will broadcast all updates already received, and future ones.
  /// It will complete if the underlying stream is finished.
  public var updates: AsyncStream<Element> {
    let (stream, continuation) = AsyncStream<Element>.makeStream()

    lock.withLock { state in
      state.subscribers.append(continuation)

      // We update the continuation from within the lock.
      // This is to ensure that there is not a race condition where the continuation is updated from another thread (new element yielded, finished)
      // before we had time to caught up with the past updates.
      //
      // While it doesn't feel great to call into external code from within a lock, this seems to have no side effect.
      for element in state.pastUpdates {
        continuation.yield(element)
      }
      if state.isFinished {
        continuation.finish()
      }
    }

    return stream
  }

  public static func Just(_ element: Element) -> BroadcastedStream<Element> {
    BroadcastedStream(Combine.Just(element).eraseToAnyPublisher()) { finish
      in finish()
    }
  }

  public func makeAsyncIterator() -> AsyncIterator {
    updates.makeAsyncIterator()
  }

  private struct InternalState: Sendable {
    var subscribers: [AsyncStream<Element>.Continuation] = []
    var pastUpdates: [Element] = []
    var isFinished = false
  }

  private let lock = OSAllocatedUnfairLock<InternalState>(initialState: InternalState())

  private let cancellables = Atomic(Set<AnyCancellable>())
  private let internalStream: AsyncStream<Element>

  /// Finish the stream, preventing further updates.
  private func finish() {
    let subscribers: [AsyncStream<Element>.Continuation] = lock.withLock { state in
      guard !state.isFinished else {
        assertionFailure("Cannot freeze an already finished BroadcastedStream")
        return []
      }
      state.isFinished = true
      return state.subscribers
    }
    for subscriber in subscribers { subscriber.finish() }
  }

  /// Broadcast a new value. It will be send to existing and future observers.
  private func broadcast(_ element: Element) {
    let subscribers: [AsyncStream<Element>.Continuation] = lock.withLock { state in
      if state.isFinished {
        assertionFailure("Cannot update a finished BroadcastedStream")
        return []
      }
      state.pastUpdates.append(element)
      return state.subscribers
    }
    for subscriber in subscribers { subscriber.yield(element) }
  }

}

extension BroadcastedStream {
  public static func makeStream(
    of _: Element.Type = Element
      .self)
    -> (stream: BroadcastedStream<Element>, continuation: AsyncStream<Element>.Continuation)
  {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    let broadcastedStream = BroadcastedStream<Element>(internalStream: stream)
    return (broadcastedStream, continuation)
  }
}
