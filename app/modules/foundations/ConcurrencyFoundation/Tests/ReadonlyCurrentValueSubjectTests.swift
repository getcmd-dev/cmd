// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import SwiftTesting
import Testing
@testable import ConcurrencyFoundation

// MARK: - ReadonlyCurrentValueSubjectTests

struct ReadonlyCurrentValueSubjectTests {

  @Test("Initializes with correct current value")
  func test_initialization() {
    let subject = CurrentValueSubject<Int, Never>(42)
    let sut = ReadonlyCurrentValueSubject(subject)

    #expect(sut.currentValue == 42)
  }

  @Test("Updates current value when publisher emits")
  func test_currentValueUpdates() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let sut = ReadonlyCurrentValueSubject(subject)

    #expect(sut.currentValue == 0)

    let updates = expectation(description: "Updates received")
    let cancellable = sut.sink { @Sendable value in
      if value == 3 {
        updates.fulfillAtMostOnce()
      }
    }

    subject.send(1)
    subject.send(2)
    subject.send(3)

    try await fulfillment(of: [updates])
    #expect(sut.currentValue == 3)
    _ = cancellable
  }

  @Test("Subscribers receive updates")
  func test_subscriberUpdates() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let sut = ReadonlyCurrentValueSubject(subject)

    let valuesReceived = Atomic<[Int]>([])
    let updates = expectation(description: "Updates received")
    let cancellable = sut.sink { @Sendable value in
      valuesReceived.mutate { $0.append(value) }
      if value == 3 {
        updates.fulfillAtMostOnce()
      }
    }

    subject.send(1)
    subject.send(2)
    subject.send(3)

    try await fulfillment(of: [updates])
    #expect(valuesReceived.value == [0, 1, 2, 3])
    _ = cancellable
  }

  @Test("Current value stays in sync with rapid updates")
  func test_rapidUpdates() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let sut = ReadonlyCurrentValueSubject(subject)

    let updates = expectation(description: "Final update received")
    let cancellable = sut.sink { @Sendable value in
      if value == 100 {
        updates.fulfillAtMostOnce()
      }
    }

    for i in 1...100 {
      subject.send(i)
    }

    try await fulfillment(of: [updates])
    #expect(sut.currentValue == 100)
    _ = cancellable
  }

  @Test("Works with struct types")
  func test_withStruct() async throws {
    struct TestData: Sendable, Equatable {
      let value: Int
      let text: String
    }

    let subject = CurrentValueSubject<TestData, Never>(TestData(value: 1, text: "first"))
    let sut = ReadonlyCurrentValueSubject(subject)

    #expect(sut.currentValue.value == 1)
    #expect(sut.currentValue.text == "first")

    let updates = expectation(description: "Update received")
    let cancellable = sut.sink { @Sendable value in
      if value.text == "second" {
        updates.fulfillAtMostOnce()
      }
    }

    subject.send(TestData(value: 2, text: "second"))

    try await fulfillment(of: [updates])
    #expect(sut.currentValue.value == 2)
    #expect(sut.currentValue.text == "second")
    _ = cancellable
  }

  @Test("Readonly extension works correctly")
  func test_readonlyExtension() async throws {
    let subject = CurrentValueSubject<String, Never>("hello")
    let sut = subject.readonly()

    #expect(sut.currentValue == "hello")

    let updates = expectation(description: "Update received")
    let cancellable = sut.sink { @Sendable value in
      if value == "world" {
        updates.fulfillAtMostOnce()
      }
    }

    subject.send("world")

    try await fulfillment(of: [updates])
    #expect(sut.currentValue == "world")
    _ = cancellable
  }

  @Test("Readonly with duplicate removal works correctly")
  func test_readonlyRemovingDuplicates() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let sut = subject.readonly(removingDuplicate: true)

    let valuesReceived = Atomic<[Int]>([])
    let updates = expectation(description: "Update received")
    let cancellable = sut.sink { @Sendable value in
      valuesReceived.mutate { $0.append(value) }
      if value == 3 {
        updates.fulfillAtMostOnce()
      }
    }

    subject.send(0) // Duplicate, should be filtered
    subject.send(1)
    subject.send(1) // Duplicate, should be filtered
    subject.send(2)
    subject.send(2) // Duplicate, should be filtered
    subject.send(3)

    try await fulfillment(of: [updates])
    #expect(valuesReceived.value == [0, 1, 2, 3])
    #expect(sut.currentValue == 3)
    _ = cancellable
  }

  @Test("Just factory method works correctly")
  func test_justFactoryMethod() async throws {
    let sut = ReadonlyCurrentValueSubject<Int>.just(42)

    #expect(sut.currentValue == 42)

    let valuesReceived = Atomic<[Int]>([])
    let updates = expectation(description: "Initial value received")
    let cancellable = sut.sink { @Sendable value in
      valuesReceived.mutate { $0.append(value) }
      updates.fulfillAtMostOnce()
    }

    try await fulfillment(of: [updates])

    #expect(valuesReceived.value == [42])
    #expect(sut.currentValue == 42)
    _ = cancellable
  }

  @Test("Thread safety for concurrent reads and updates")
  func test_threadSafety() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let sut = ReadonlyCurrentValueSubject(subject)

    let didReadManyTimes = expectation(description: "Did read many times")
    let didReceiveAllUpdates = expectation(description: "Did receive all updates")

    let updatesCount = Atomic(0)
    let cancellable = sut.sink { @Sendable _ in
      let count = updatesCount.increment()
      if count == 50 {
        didReceiveAllUpdates.fulfill()
      }
    }

    Task.detached {
      for i in 1...50 {
        subject.send(i)
        try? await Task.sleep(nanoseconds: 1_000_000)
      }
    }

    Task {
      for _ in 1...50 {
        _ = sut.currentValue
        try? await Task.sleep(nanoseconds: 1_000_000)
      }
      didReadManyTimes.fulfill()
    }

    try await fulfillment(of: [didReadManyTimes, didReceiveAllUpdates])
    #expect(sut.currentValue == 50)
    _ = cancellable
  }

  @Test("Current value reflects latest publisher value even without subscribers")
  func test_currentValueWithoutSubscribers() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let sut = ReadonlyCurrentValueSubject(subject)

    #expect(sut.currentValue == 0)

    let intermediateUpdate = expectation(description: "Intermediate update")
    var cancellableTemp: AnyCancellable? = sut.sink { @Sendable value in
      if value == 20 {
        intermediateUpdate.fulfillAtMostOnce()
      }
    }

    subject.send(10)
    subject.send(20)

    try await fulfillment(of: [intermediateUpdate])
    #expect(sut.currentValue == 20)
    cancellableTemp = nil

    // Now subscribe again and verify we get the latest value
    let valuesReceived = Atomic<[Int]>([])
    let updates = expectation(description: "Update received")
    let cancellable = sut.sink { @Sendable value in
      valuesReceived.mutate { $0.append(value) }
      if value == 30 {
        updates.fulfillAtMostOnce()
      }
    }

    subject.send(30)

    try await fulfillment(of: [updates])
    #expect(valuesReceived.value.contains(20)) // Should receive current value
    #expect(valuesReceived.value.contains(30))
    #expect(sut.currentValue == 30)
    _ = cancellable
  }

  @Test("Multiple subscribers receive same updates")
  func test_multipleSubscribers() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let sut = ReadonlyCurrentValueSubject(subject)

    let valuesReceived1 = Atomic<[Int]>([])
    let valuesReceived2 = Atomic<[Int]>([])
    let updates1 = expectation(description: "Updates received 1")
    let updates2 = expectation(description: "Updates received 2")

    let cancellable1 = sut.sink { @Sendable value in
      valuesReceived1.mutate { $0.append(value) }
      if value == 3 {
        updates1.fulfillAtMostOnce()
      }
    }

    let cancellable2 = sut.sink { @Sendable value in
      valuesReceived2.mutate { $0.append(value) }
      if value == 3 {
        updates2.fulfillAtMostOnce()
      }
    }

    subject.send(1)
    subject.send(2)
    subject.send(3)

    try await fulfillment(of: [updates1, updates2])
    #expect(valuesReceived1.value == [0, 1, 2, 3])
    #expect(valuesReceived2.value == [0, 1, 2, 3])
    #expect(sut.currentValue == 3)
    _ = cancellable1
    _ = cancellable2
  }
}
