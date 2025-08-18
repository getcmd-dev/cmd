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
    let valuesReceived = expectation(description: "All values received")
    let stream1Completed = expectation(description: "Stream 1 completed")
    let stream2Completed = expectation(description: "Stream 2 completed")

    var values1: [Int] = []
    var values2: [Int] = []

    Task {
      for await value in stream {
        values1.append(value)
      }
      stream1Completed.fulfill()
    }
    Task {
      for await value in stream {
        values2.append(value)
      }
      stream2Completed.fulfill()
    }

    for i in 0..<5 {
      continuation.yield(i)
    }

    // Wait a bit to ensure values are received
    try await Task.sleep(for: .milliseconds(100))
    valuesReceived.fulfill()

    continuation.finish()
    try await fulfillment(of: [valuesReceived, stream1Completed, stream2Completed])

    #expect(values1 == [0, 1, 2, 3, 4])
    #expect(values2 == [0, 1, 2, 3, 4])
  }

  @Test("Stream receives already emitted values")
  func test_streamHistory() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)
    for i in 0..<5 {
      continuation.yield(i)
    }
    continuation.finish()

    var values = [Int]()
    for await i in stream {
      values.append(i)
    }

    #expect(values == [0, 1, 2, 3, 4])
  }

  @Test("Late subscribers receive full history")
  func test_lateSubscriber() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // First emit some values
    for i in 0..<3 {
      continuation.yield(i)
    }

    // Late subscriber should receive all previous values
    var lateValues = [Int]()
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    Task {
      for await value in stream {
        lateValues.append(value)
      }
      lateSubscriberDone.fulfill()
    }

    // Emit more values
    for i in 3..<5 {
      continuation.yield(i)
    }

    continuation.finish()
    try await fulfillment(of: [lateSubscriberDone])

    #expect(lateValues == [0, 1, 2, 3, 4])
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
    var receivedValues = [Int]()

    Task {
      for await value in stream {
        receivedValues.append(value)
        if receivedValues.count == 3 {
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
    #expect(receivedValues == [1, 2, 3])
  }

  @Test("Just stream")
  func test_just() async throws {
    let stream = BroadcastedStream.Just(42)
    var values = [Int]()
    let completion = expectation(description: "Stream completed")

    Task {
      for await value in stream {
        values.append(value)
      }
      completion.fulfill()
    }

    try await fulfillment(of: [completion])
    #expect(values == [42])
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

    // Emit some values before subscribing
    for i in 0..<3 {
      continuation.yield(i)
    }

    // Late subscriber should not receive previous values
    var lateValues = [Int]()
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    Task {
      for await value in stream {
        lateValues.append(value)
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
    #expect(lateValues == [3, 4])
  }

  @Test("ReplayStrategy.replayLast only replays the most recent value")
  func test_replayLastStrategy() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayLast)

    // Emit multiple values
    for i in 0..<5 {
      continuation.yield(i)
    }

    // Late subscriber should only receive the last value
    var lateValues = [Int]()
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    Task {
      for await value in stream {
        lateValues.append(value)
      }
      lateSubscriberDone.fulfill()
    }

    // Emit one more value
    continuation.yield(10)
    continuation.finish()

    try await fulfillment(of: [lateSubscriberDone])

    // Should receive the last value (4) and the new value (10)
    #expect(lateValues == [4, 10])
  }

  @Test("ReplayStrategy.replayAll replays all past values")
  func test_replayAllStrategy() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // Emit some values
    for i in 0..<3 {
      continuation.yield(i)
    }

    // Late subscriber should receive all previous values
    var lateValues = [Int]()
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    Task {
      for await value in stream {
        lateValues.append(value)
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
    #expect(lateValues == [0, 1, 2, 3, 4])
  }

  @Test("Multiple subscribers with different repeat strategies")
  func test_multipleSubscribersWithStrategies() async throws {
    // Test that multiple streams with different strategies work independently
    let (noReplayStream, noReplayContinuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .noReplay)
    let (replayLastStream, replayLastContinuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayLast)
    let (replayAllStream, replayAllContinuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // Emit values to all streams
    for i in 0..<3 {
      noReplayContinuation.yield(i)
      replayLastContinuation.yield(i)
      replayAllContinuation.yield(i)
    }

    // Wait a bit to ensure values are processed
    try await Task.sleep(for: .milliseconds(10))

    var noReplayValues = [Int]()
    var replayLastValues = [Int]()
    var replayAllValues = [Int]()

    let noReplayDone = expectation(description: "NoReplay subscriber completed")
    let replayLastDone = expectation(description: "ReplayLast subscriber completed")
    let replayAllDone = expectation(description: "ReplayAll subscriber completed")

    Task {
      for await value in noReplayStream {
        noReplayValues.append(value)
      }
      noReplayDone.fulfill()
    }

    Task {
      for await value in replayLastStream {
        replayLastValues.append(value)
      }
      replayLastDone.fulfill()
    }

    Task {
      for await value in replayAllStream {
        replayAllValues.append(value)
      }
      replayAllDone.fulfill()
    }

    // Wait a bit to ensure subscriptions are active
    try await Task.sleep(for: .milliseconds(10))

    // Add one more value to each
    noReplayContinuation.yield(10)
    replayLastContinuation.yield(10)
    replayAllContinuation.yield(10)

    // Finish all streams
    noReplayContinuation.finish()
    replayLastContinuation.finish()
    replayAllContinuation.finish()

    try await fulfillment(of: [noReplayDone, replayLastDone, replayAllDone])

    #expect(noReplayValues == [10]) // Only new value
    #expect(replayLastValues == [2, 10]) // Last value + new value
    #expect(replayAllValues == [0, 1, 2, 10]) // All values + new value
  }

  @Test("Iterator cleanup prevents memory leaks")
  func test_iteratorCleanup() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // Create and immediately drop many iterators to test cleanup
    for i in 0..<100 {
      continuation.yield(i)

      // Create iterator but don't consume it fully - this should still clean up
      let iterator = stream.makeAsyncIterator()
      _ = iterator
      // Iterator goes out of scope, should trigger cancellable cleanup
    }

    // Verify the stream still works properly after many abandoned iterators
    var finalValues = [Int]()
    let finalSubscriberDone = expectation(description: "Final subscriber completed")

    Task {
      for await value in stream {
        finalValues.append(value)
        if finalValues.count >= 5 { break } // Just take first 5 to avoid long test
      }
      finalSubscriberDone.fulfill()
    }

    try await fulfillment(of: [finalSubscriberDone])
    continuation.finish()

    #expect(finalValues == [0, 1, 2, 3, 4])
  }

  @Test("eraseToStream creates independent stream")
  func test_eraseToStream() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // Emit some values
    for i in 0..<3 {
      continuation.yield(i)
    }

    // Create an erased stream
    let erasedStream = stream.eraseToStream()

    var erasedValues = [Int]()
    let erasedDone = expectation(description: "Erased stream completed")

    Task {
      for await value in erasedStream {
        erasedValues.append(value)
      }
      erasedDone.fulfill()
    }

    // Add more values
    for i in 3..<5 {
      continuation.yield(i)
    }

    continuation.finish()
    try await fulfillment(of: [erasedDone])

    #expect(erasedValues == [0, 1, 2, 3, 4])
  }

  @Test("Concurrent subscribers receive all values consistently")
  func test_concurrentSubscribers() async throws {
    let (stream, continuation) = BroadcastedStream<Int>.makeStream(replayStrategy: .replayAll)

    // Simple test with two subscribers to verify concurrent access works
    var values1 = [Int]()
    var values2 = [Int]()

    let subscriber1Done = expectation(description: "Subscriber 1 completed")
    let subscriber2Done = expectation(description: "Subscriber 2 completed")

    // Start first subscriber
    Task {
      for await value in stream {
        values1.append(value)
      }
      subscriber1Done.fulfill()
    }

    // Start second subscriber
    Task {
      for await value in stream {
        values2.append(value)
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
    #expect(values1 == expectedValues, "Subscriber 1 received \(values1) instead of \(expectedValues)")
    #expect(values2 == expectedValues, "Subscriber 2 received \(values2) instead of \(expectedValues)")
  }
}
