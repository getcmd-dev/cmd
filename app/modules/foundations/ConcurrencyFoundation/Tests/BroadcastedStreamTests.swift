// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import SwiftTesting
import Testing
@testable import ConcurrencyFoundation

// MARK: - BroadcastedStreamTests

struct BroadcastedStreamTests {
  @Test("Stream can be multiplexed")
  func test_multiplex() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)
    let stream1Completed = expectation(description: "Stream 1 completed")
    let stream2Completed = expectation(description: "Stream 2 completed")

    let values1 = Atomic<[Int]>([])
    let values2 = Atomic<[Int]>([])

    var firstIterator = stream.makeAsyncIterator()
    Task {
      while let value = await firstIterator.next() {
        values1.mutate { $0.append(value) }
      }
      stream1Completed.fulfill()
    }

    var secondIterator = stream.makeAsyncIterator()
    Task {
      while let value = await secondIterator.next() {
        values2.mutate { $0.append(value) }
      }
      stream2Completed.fulfill()
    }

    for i in 0..<5 {
      continuation.yield(i)
    }

    continuation.finish()
    try await fulfillment(of: [stream1Completed, stream2Completed])

    #expect(values1.value == [0, 1, 2, 3, 4])
    #expect(values2.value == [0, 1, 2, 3, 4])
  }

  @Test("Stream receives already emitted values")
  func test_streamHistory() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)
    for i in 0..<5 {
      continuation.yield(i)
    }
    continuation.finish()

    let values = Atomic<[Int]>([])
    for await i in stream {
      values.mutate { $0.append(i) }
    }

    #expect(values.value == [0, 1, 2, 3, 4])
  }

  @Test("Late subscribers receive full history")
  func test_lateSubscriber() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // First emit some values
    for i in 0..<3 {
      continuation.yield(i)
    }

    // Late subscriber should receive all previous values
    let lateValues = Atomic<[Int]>([])
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    Task {
      for await value in stream {
        lateValues.mutate { $0.append(value) }
      }
      lateSubscriberDone.fulfill()
    }

    // Emit more values
    for i in 3..<5 {
      continuation.yield(i)
    }

    continuation.finish()
    try await fulfillment(of: [lateSubscriberDone])

    #expect(lateValues.value == [0, 1, 2, 3, 4])
  }

  @Test("Stream from publisher")
  func test_publisherStream() async throws {
    let subject = PassthroughSubject<Int, Never>()
    var freezeStream: (() -> Void)?

    let stream = BroadcastedStream(replayStrategy: .replayAll, subject.eraseToAnyPublisher()) { finish in
      freezeStream = finish
    }

    let valuesReceived = expectation(description: "Values received")
    let streamFinished = expectation(description: "Stream finished received")
    let receivedValues = Atomic<[Int]>([])

    Task {
      for await value in stream {
        receivedValues.mutate { $0.append(value) }
        if receivedValues.value.count == 3 {
          valuesReceived.fulfill()
        }
      }
      streamFinished.fulfill()
    }

    subject.send(1)
    subject.send(2)
    subject.send(3)
    try await fulfillment(of: [valuesReceived])
    freezeStream?()

    try await fulfillment(of: [streamFinished])
    #expect(receivedValues.value == [1, 2, 3])
  }

  @Test("Just stream")
  func test_just() async throws {
    let stream = BroadcastedStream.Just(42)
    let values = Atomic<[Int]>([])
    let completion = expectation(description: "Stream completed")

    Task {
      for await value in stream {
        values.mutate { $0.append(value) }
      }
      completion.fulfill()
    }

    try await fulfillment(of: [completion])
    #expect(values.value == [42])
  }

  @Test("Stream finishes for all subscribers")
  func test_completion() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)
    let sub1Done = expectation(description: "Subscriber 1 completed")
    let sub2Done = expectation(description: "Subscriber 2 completed")

    Task {
      for await _ in stream { }
      sub1Done.fulfill()
    }

    Task {
      for await _ in stream { }
      sub2Done.fulfill()
    }

    continuation.yield(1)
    continuation.finish()

    try await fulfillment(of: [sub1Done, sub2Done])
  }

  @Test("ReplayStrategy.noReplay doesn't replay past values")
  func test_noReplayStrategy() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .noReplay)

    let firstBatchProcessed = stream.expectToYield(2)

    // Emit some values before subscribing
    for i in 0..<3 {
      continuation.yield(i)
    }

    // We need to track when the first batch of updates has been processed.
    // This is because the `BroadcastStream` uses an internal `AsyncStream` and events sent to its continuation are not synchronously
    // sent to its listener. i.e. immediately after calling `continuation.yield(i)` the `BroadcastStream` might not yet have received the event.
    try await fulfillment(of: firstBatchProcessed)

    // Late subscriber should not receive previous values
    let lateValues = Atomic<[Int]>([])
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    // Create the iterator sync to ensure that is is created before yielding new values.
    var lateIterator = stream.makeAsyncIterator()
    Task {
      while let value = await lateIterator.next() {
        lateValues.mutate { $0.append(value) }
      }
      lateSubscriberDone.fulfill()
    }

    // Emit more values after subscribing
    for i in 3..<5 {
      continuation.yield(i)
    }

    continuation.finish()
    try await fulfillment(of: [lateSubscriberDone])

    // Should only receive values after subscription
    #expect(lateValues.value == [3, 4])
  }

  @Test("ReplayStrategy.replayLast only replays the most recent value")
  func test_replayLastStrategy() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayLast)

    let firstBatchProcessed = stream.expectToYield(4)

    // Emit multiple values
    for i in 0..<5 {
      continuation.yield(i)
    }

    // We need to track when the first batch of updates has been processed.
    // This is because the `BroadcastStream` uses an internal `AsyncStream` and events sent to its continuation are not synchronously
    // sent to its listener. i.e. immediately after calling `continuation.yield(i)` the `BroadcastStream` might not yet have received the event.
    try await fulfillment(of: firstBatchProcessed)

    // Late subscriber should only receive the last value
    let lateValues = Atomic<[Int]>([])
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    // Create the iterator sync to ensure that is is created before yielding new values.
    var lateIterator = stream.makeAsyncIterator()
    Task {
      while let value = await lateIterator.next() {
        lateValues.mutate { $0.append(value) }
      }
      lateSubscriberDone.fulfill()
    }

    // Emit one more value
    continuation.yield(10)
    continuation.finish()

    try await fulfillment(of: [lateSubscriberDone])

    // Should receive the last value (4) and the new value (10)
    #expect(lateValues.value == [4, 10])
  }

  @Test("ReplayStrategy.replayAll replays all past values")
  func test_replayAllStrategy() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // Emit some values
    for i in 0..<3 {
      continuation.yield(i)
    }

    // Late subscriber should receive all previous values
    let lateValues = Atomic<[Int]>([])
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    Task {
      for await value in stream {
        lateValues.mutate { $0.append(value) }
      }
      lateSubscriberDone.fulfill()
    }

    // Emit more values
    for i in 3..<5 {
      continuation.yield(i)
    }

    continuation.finish()
    try await fulfillment(of: [lateSubscriberDone])

    // Should receive all values
    #expect(lateValues.value == [0, 1, 2, 3, 4])
  }

  @Test("Multiple subscribers with different repeat strategies")
  func test_multipleSubscribersWithStrategies() async throws {
    // Test that multiple streams with different strategies work independently
    let (noReplayStream, noReplayContinuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .noReplay)
    let (replayLastStream, replayLastContinuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayLast)
    let (replayAllStream, replayAllContinuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    let setupExp = [
      noReplayStream.expectToYield(2),
      replayLastStream.expectToYield(2),
      replayAllStream.expectToYield(2),
    ]

    // Emit values to all streams
    for i in 0..<3 {
      noReplayContinuation.yield(i)
      replayLastContinuation.yield(i)
      replayAllContinuation.yield(i)
    }

    // We need to track when the first batch of update has been processed.
    // This is because the `BroadcastStream` uses an internal `AsyncStream` and events sent to its continuation are not synchronously
    // sent to its listener. i.e. immediately after calling `continuation.yield(i)` the `BroadcastStream` might not yet have received the event.
    try await fulfillment(of: setupExp)

    let noReplayValues = Atomic<[Int]>([])
    let replayLastValues = Atomic<[Int]>([])
    let replayAllValues = Atomic<[Int]>([])

    let noReplayDone = expectation(description: "NoReplay subscriber completed")
    let replayLastDone = expectation(description: "ReplayLast subscriber completed")
    let replayAllDone = expectation(description: "ReplayAll subscriber completed")

    var noReplayIterator = noReplayStream.makeAsyncIterator()
    var replayLastIterator = replayLastStream.makeAsyncIterator()
    var replayAllIterator = replayAllStream.makeAsyncIterator()

    Task {
      while let value = await noReplayIterator.next() {
        noReplayValues.mutate { $0.append(value) }
      }
      noReplayDone.fulfill()
    }

    Task {
      while let value = await replayLastIterator.next() {
        replayLastValues.mutate { $0.append(value) }
      }
      replayLastDone.fulfill()
    }

    Task {
      while let value = await replayAllIterator.next() {
        replayAllValues.mutate { $0.append(value) }
      }
      replayAllDone.fulfill()
    }

    // Add one more value to each
    noReplayContinuation.yield(10)
    replayLastContinuation.yield(10)
    replayAllContinuation.yield(10)

    // Finish all streams
    noReplayContinuation.finish()
    replayLastContinuation.finish()
    replayAllContinuation.finish()

    try await fulfillment(of: [noReplayDone, replayLastDone, replayAllDone])

    #expect(noReplayValues.value == [10]) // Only new value
    #expect(replayLastValues.value == [2, 10]) // Last value + new value
    #expect(replayAllValues.value == [0, 1, 2, 10]) // All values + new value
  }

  @Test("eraseToStream creates independent stream")
  func test_eraseToStream() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    let exp = stream.expectToYield(2)

    // Emit some values
    for i in 0..<3 {
      continuation.yield(i)
    }
    // We need to track when the first batch of update has been processed.
    // This is because the `BroadcastStream` uses an internal `AsyncStream` and events sent to its continuation are not synchronously
    // sent to its listener. i.e. immediately after calling `continuation.yield(i)` the `BroadcastStream` might not yet have received the event.
    try await fulfillment(of: exp)

    // Create an erased stream
    let erasedStream = stream.eraseToStream()

    let erasedValues = Atomic<[Int]>([])
    let erasedDone = expectation(description: "Erased stream completed")

    var iterator = erasedStream.makeAsyncIterator()
    Task {
      while let value = await iterator.next() {
        erasedValues.mutate { $0.append(value) }
      }
      erasedDone.fulfill()
    }

    // Add more values
    for i in 3..<5 {
      continuation.yield(i)
    }

    continuation.finish()
    try await fulfillment(of: [erasedDone])

    #expect(erasedValues.value == [0, 1, 2, 3, 4])
  }

  @Test("Concurrent subscribers receive all values consistently")
  func test_concurrentSubscribers() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // Simple test with two subscribers to verify concurrent access works
    let values1 = Atomic<[Int]>([])
    let values2 = Atomic<[Int]>([])

    let subscriber1Done = expectation(description: "Subscriber 1 completed")
    let subscriber2Done = expectation(description: "Subscriber 2 completed")

    // Start first subscriber
    var firstIterator = stream.makeAsyncIterator()
    Task {
      while let value = await firstIterator.next() {
        values1.mutate { $0.append(value) }
      }
      subscriber1Done.fulfill()
    }

    // Start second subscriber
    var secondIterator = stream.makeAsyncIterator()
    Task {
      while let value = await secondIterator.next() {
        values2.mutate { $0.append(value) }
      }
      subscriber2Done.fulfill()
    }

    // Emit values
    for i in 0..<5 {
      continuation.yield(i)
    }

    continuation.finish()
    try await fulfillment(of: [subscriber1Done, subscriber2Done])

    // Both subscribers should receive the same values
    let expectedValues = Array(0..<5)
    #expect(values1.value == expectedValues, "Subscriber 1 received \(values1.value) instead of \(expectedValues)")
    #expect(values2.value == expectedValues, "Subscriber 2 received \(values2.value) instead of \(expectedValues)")
  }
}
