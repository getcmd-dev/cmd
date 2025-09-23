// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import Foundation
import os

// MARK: - BroadcastedStream

/// An `AsyncSequence` that can be independently consummed by several iterators.
/// (In contrast, an `AsyncStream` behaves more like an iterator and can only be iterated over once. In certain cases this can be limiting and even error-prone)
/// The `BroadcastedStream` can be configured during initialization to send all past values, only the last one or none of them when
/// making an iterator. Future values are always sent to the iterator.
public final class BroadcastedStream<Element: Sendable>: AsyncSequence, Sendable {

  public convenience init(replayStrategy: ReplayStrategy, _: Element.Type = Element.self, _ build: (Continuation) -> Void) {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    self.init(replayStrategy: replayStrategy, internalStream: stream)

    build(continuation)
  }

  /// Initialize with a publisher that emits updates.
  public convenience init(
    replayStrategy: ReplayStrategy,
    _ publisher: AnyPublisher<Element, Never>,
    _ finish: (@escaping () -> Void) -> Void)
  {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    self.init(replayStrategy: replayStrategy, internalStream: stream)

    let cancellable = publisher.sink { element in
      continuation.yield(element)
    }
    cancellables.mutate { $0.insert(cancellable) }

    finish { continuation.finish() }
  }

  /// Initialize with a stream that emits updates, and signal when the updates are done.
  public convenience init(replayStrategy: ReplayStrategy, _ stream: AsyncStream<Element>) {
    self.init(replayStrategy: replayStrategy, internalStream: stream)
  }

  private init(replayStrategy: ReplayStrategy, internalStream: AsyncStream<Element>) {
    self.replayStrategy = replayStrategy
    self.internalStream = internalStream

    var iterator = internalStream.makeAsyncIterator()
    Task { [weak self] in
      while let element = await iterator.next() {
        if self == nil {
          os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "UnknownApp", category: "command")
            .warning(
              "The BroadcastedStream received an event after being deallocated. It will not be forwarded to its subscribers.")
        }
        self?.broadcast(element)
      }
      self?.finish()
    }
  }

  public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
  public typealias Failure = Never
  public typealias Continuation = AsyncStream<Element>.Continuation

  public let replayStrategy: ReplayStrategy

  public static func Just(_ element: Element) -> BroadcastedStream<Element> {
    BroadcastedStream(replayStrategy: .replayAll, Combine.Just(element).eraseToAnyPublisher()) { finish
      in finish()
    }
  }

  /// The events as an async stream.
  /// Creating a stream doesn't interfer with other subscribers
  public func eraseToStream() -> AsyncStream<Element> {
    var iterator = Iterator<Element>(iterator: makeAsyncIterator(), cancellable: AnyCancellable { })
    return iterator.stream()
  }

  public func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    let id = UUID()

    lock.withLock { state in
      state.subscribers[id] = continuation

      let pastUpdatesToReplay: [Element] =
        switch replayStrategy {
        case .noReplay: []
        case .replayAll: state.pastUpdates
        case .replayLast: state.pastUpdates.last.map { [$0] } ?? []
        }

      // We update the continuation from within the lock.
      // This is to ensure that there is not a race condition where the continuation is updated from another thread (new element yielded, finished)
      // before we had time to caught up with the past updates.
      //
      // While it doesn't feel great to call into external code from within a lock, this seems to have no side effect.
      for element in pastUpdatesToReplay {
        continuation.yield(element)
      }
      if state.isFinished {
        continuation.finish()
      }
    }

    let cancellable = AnyCancellable {
      // It is intentional to retain self here, as we don't want to re-reference while being iterated over.
      _ = self.lock.withLock { state in
        state.subscribers.removeValue(forKey: id)
      }
    }
    var iterator = Iterator<Element>(iterator: stream.makeAsyncIterator(), cancellable: cancellable)
    return iterator.stream().makeAsyncIterator()
  }

  private struct InternalState: Sendable {
    var subscribers = [UUID: AsyncStream<Element>.Continuation]()
    var pastUpdates = [Element]()
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
      return Array(state.subscribers.values)
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
      switch replayStrategy {
      case .noReplay:
        break
      case .replayAll:
        state.pastUpdates.append(element)
      case .replayLast:
        state.pastUpdates = [element]
      }
      return Array(state.subscribers.values)
    }
    for subscriber in subscribers { subscriber.yield(element) }
  }

}

extension BroadcastedStream {
  public static func makeStream(
    of _: Element.Type = Element.self,
    replayStrategy: ReplayStrategy)
    -> (stream: BroadcastedStream<Element>, continuation: AsyncStream<Element>.Continuation)
  {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    let broadcastedStream = BroadcastedStream<Element>(replayStrategy: replayStrategy, internalStream: stream)
    return (broadcastedStream, continuation)
  }
}

// MARK: - Iterator

/// An iterator that will cancel the attached cancellabled when re-referenced.
public struct Iterator<Element: Sendable>: AsyncIteratorProtocol {
  var iterator: AsyncStream<Element>.AsyncIterator
  let cancellable: AnyCancellable

  public mutating func next() async -> Element? {
    await iterator.next()
  }
}

extension Iterator {
  mutating func stream() -> AsyncStream<Self.Element> {
    var iterator = self
    return AsyncStream<Self.Element> { continuation in
      Task {
        while let nextValue = await iterator.next() {
          continuation.yield(nextValue)
        }
        continuation.finish()
      }
    }
  }
}
