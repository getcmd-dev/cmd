// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import SwiftTesting
import Testing
@testable import ConcurrencyFoundation

// MARK: - CurrentValueStreamTests

struct CurrentValueStreamTests {
  @Test("CurrentValueStream maintains current value and broadcasts updates")
  func test_currentValueAndUpdates() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let stream = CurrentValueStream(value: subject)

    #expect(stream.value == 0)

    let valuesReceived = expectation(description: "Values received")
    let receivedValues = Atomic<[Int]>([])

    // Create the iterator sync to ensure that is is created before yielding new values.
    var iterator = stream.futureUpdates.makeAsyncIterator()
    Task {
      while let value = await iterator.next() {
        receivedValues.mutate { $0.append(value) }
        if receivedValues.value.count == 3 {
          valuesReceived.fulfill()
        }
      }
    }

    subject.send(1)
    subject.send(2)

    try await fulfillment(of: [valuesReceived])
    #expect(receivedValues.value == [0, 1, 2])
    #expect(stream.value == 2)
  }

  @Test("CurrentValueStream supports multiple subscribers")
  func test_multipleSubscribers() async throws {
    let (stream, continuation) = CurrentValueStream.makeStream(initial: 0)
    var counter = 0
    let valuesReceived = expectation(description: "All values received")

    let inc: @Sendable () -> Void = {
      Task { @MainActor in
        counter += 1
        if counter == 10 { // 5 values × 2 subscribers
          valuesReceived.fulfill()
        }
      }
    }

    // Create the iterators sync to ensure that is is created before yielding new values.
    var iterator1 = stream.futureUpdates.makeAsyncIterator()
    Task {
      while await iterator1.next() != nil {
        inc()
      }
    }

    var iterator2 = stream.futureUpdates.makeAsyncIterator()
    Task {
      while await iterator2.next() != nil {
        inc()
      }
    }

    for i in 1...5 {
      continuation.yield(i)
    }

    try await fulfillment(of: [valuesReceived])
    #expect(stream.value == 5)
  }

  @Test("CurrentValueStream dynamic member lookup")
  func test_dynamicMemberLookup() async throws {
    struct TestStruct {
      let value: Int
      let text: String
    }

    let initial = TestStruct(value: 1, text: "test")
    let stream = CurrentValueStream.Just(initial)

    #expect(stream.value.value == 1)
    #expect(stream.text == "test")
  }

  @Test("last value")
  func test_lastValue() async throws {
    let (stream, continuation) = CurrentValueStream<Int>.makeStream(initial: 1)
    continuation.yield(2)
    continuation.finish()

    #expect(await stream.lastValue == 2)
  }

  @Test("last value is the first value when the stream has no updates")
  func test_lastValue_unchangedStream() async throws {
    let (stream, continuation) = CurrentValueStream<Int>.makeStream(initial: 1)
    continuation.finish()

    #expect(await stream.lastValue == 1)
  }

  @Test("last value is the fixed value with Just")
  func test_lastValue_justStream() async throws {
    let stream = CurrentValueStream<Int>.Just(1)
    #expect(await stream.lastValue == 1)
  }

  @Test("Just updates complete immediately")
  func test_justStream_hasNoUpdates() async throws {
    let stream = CurrentValueStream<Int>.Just(1)
    let updatesCount = Atomic(0)
    for await _ in stream.futureUpdates {
      updatesCount.increment()
    }
    #expect(updatesCount.value == 1)
  }

  @Test("CurrentValueStream with configurable ReplayStrategy - replayLast (default)")
  func test_replayStrategyReplayLast() async throws {
    let (stream, continuation) = CurrentValueStream<Int>.makeStream(initial: 0)

    // Emit some updates
    let exp = stream.futureUpdates.expectToYield(3)
    continuation.yield(1)
    continuation.yield(2)
    continuation.yield(3)

    // We need to track when the first batch of updates has been processed.
    // This is because the stream uses an internal `AsyncStream` and events sent to its continuation are not synchronously
    // sent to its listener. i.e. immediately after calling `continuation.yield(i)` the `BroadcastStream` might not yet have received the event.
    try await fulfillment(of: exp)

    // Late subscriber should receive current value and new updates
    let lateValues = Atomic<[Int]>([])
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    // Create the iterator sync to ensure that is is created before yielding new values.
    var iterator = stream.futureUpdates.makeAsyncIterator()
    Task {
      while let value = await iterator.next() {
        lateValues.mutate { $0.append(value) }
      }
      lateSubscriberDone.fulfill()
    }

    // Emit one more update
    continuation.yield(4)
    continuation.finish()

    try await fulfillment(of: [lateSubscriberDone])

    // Should receive the last value (3) and the new value (4)
    #expect(lateValues.value == [3, 4])
  }

  @MainActor
  @Test("CurrentValueStream with ReplayStrategy.noReplay")
  func test_replayStrategyNoReplay() async throws {
    let (stream, continuation) = CurrentValueStream<Int>.makeStream(initial: 0, replayStrategy: .noReplay)

    // Emit some updates
    let exp = stream.futureUpdates.expectToYield(3)
    continuation.yield(1)
    continuation.yield(2)
    continuation.yield(3)

    // We need to track when the first batch of updates has been processed.
    // This is because the stream uses an internal `AsyncStream` and events sent to its continuation are not synchronously
    // sent to its listener. i.e. immediately after calling `continuation.yield(i)` the `BroadcastStream` might not yet have received the event.
    try await fulfillment(of: exp)

    // Late subscriber should not receive past values
    var lateValues = [Int]()
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    var iterator = stream.futureUpdates.makeAsyncIterator()
    Task {
      while let value = await iterator.next() {
        lateValues.append(value)
      }
      lateSubscriberDone.fulfill()
    }

    // Emit one more update
    continuation.yield(4)
    continuation.finish()

    try await fulfillment(of: [lateSubscriberDone])

    // Should only receive new values after subscription
    #expect(lateValues == [4])
  }

  @Test("CurrentValueStream with ReplayStrategy.replayAll")
  func test_replayStrategyReplayAll() async throws {
    let (stream, continuation) = CurrentValueStream<Int>.makeStream(initial: 0, replayStrategy: .replayAll)

    // Emit some updates
    let exp = stream.futureUpdates.expectToYield(3)
    continuation.yield(1)
    continuation.yield(2)
    continuation.yield(3)

    // We need to track when the first batch of updates has been processed.
    // This is because the stream uses an internal `AsyncStream` and events sent to its continuation are not synchronously
    // sent to its listener. i.e. immediately after calling `continuation.yield(i)` the `BroadcastStream` might not yet have received the event.
    try await fulfillment(of: exp)

    // Late subscriber should receive all past values
    let lateValues = Atomic<[Int]>([])
    let lateSubscriberDone = expectation(description: "Late subscriber completed")

    var iterator = stream.futureUpdates.makeAsyncIterator()
    Task {
      while let value = await iterator.next() {
        lateValues.mutate { $0.append(value) }
      }
      lateSubscriberDone.fulfill()
    }

    // Emit one more update
    continuation.yield(4)
    continuation.finish()

    try await fulfillment(of: [lateSubscriberDone])

    // Should receive all values including initial value
    #expect(lateValues.value == [1, 2, 3, 4])
  }
}

// MARK: - MutableCurrentValueStreamTests

struct MutableCurrentValueStreamTests {
  @Test("MutableCurrentValueStream can be updated")
  func test_update() async throws {
    let stream = MutableCurrentValueStream(0)
    #expect(stream.value == 0)

    let updates = expectation(description: "Updates received")
    let receivedValues = Atomic<[Int]>([])

    var iterator = stream.futureUpdates.makeAsyncIterator()
    Task {
      while let value = await iterator.next() {
        receivedValues.mutate { $0.append(value) }
        if receivedValues.value.count == 3 {
          updates.fulfill()
        }
      }
    }

    stream.update(with: 1)
    stream.update(with: 2)
    stream.update(with: 3)

    try await fulfillment(of: [updates])
    #expect(receivedValues.value == [1, 2, 3])
    #expect(stream.value == 3)
  }

  @Test("MutableCurrentValueStream can be finished")
  func test_finish() async throws {
    let stream = MutableCurrentValueStream(0)
    let completion = expectation(description: "Stream completed")

    var iterator = stream.futureUpdates.makeAsyncIterator()
    Task {
      var count = 0
      while await iterator.next() != nil {
        count += 1
      }
      #expect(count == 2)
      completion.fulfill()
    }

    stream.update(with: 1)
    stream.update(with: 2)
    stream.finish()

    try await fulfillment(of: [completion])
  }

  @Test("MutableCurrentValueStream maintains value after finish")
  func test_valueAfterFinish() async throws {
    let stream = MutableCurrentValueStream(0)
    stream.update(with: 42)
    stream.finish()

    #expect(stream.value == 42)
  }
}
