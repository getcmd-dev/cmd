// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Observation
import SwiftTesting
import Testing
@testable import ConcurrencyFoundation

// MARK: - ObservableValueTests

@MainActor
struct ObservableValueTests {
  @Test("ObservableValue initializes with value")
  func test_initialization() {
    let observable = ObservableValue(42)
    #expect(observable.value == 42)
  }

  @Test("ObservableValue updates from publisher")
  func test_publisherUpdates() async throws {
    let subject = PassthroughSubject<Int, Never>()
    let observable = ObservableValue(subject.eraseToAnyPublisher(), initial: 0)

    #expect(observable.value == 0)

    let updates = expectation(description: "Updates received")

    let cancellable = observable.observeChanges(to: \.value) { value in
      if value == 3 {
        updates.fulfill()
      }
    }
    defer { cancellable.cancel() }

    subject.send(1)
    subject.send(2)
    subject.send(3)

    try await fulfillment(of: [updates])
    #expect(observable.value == 3)
  }

  @Test("ObservableValue updates from async stream")
  func test_streamUpdates() async throws {
    let (stream, continuation) = AsyncStream<Int>.makeStream()
    let observable = ObservableValue(initial: 0, updates: stream)

    #expect(observable.value == 0)

    let updates = expectation(description: "Updates received")
    let values = Atomic([Int]())

    let cancellable = observable.observeChanges(to: \.value) { value in
      let count = values.mutate {
        $0.append(value)
        return $0.count
      }
      if count == 3 {
        updates.fulfill()
      }
    }
    defer { cancellable.cancel() }

    continuation.yield(1)
    continuation.yield(2)
    continuation.yield(3)

    try await fulfillment(of: [updates])
    #expect(values.value == [1, 2, 3])
    #expect(observable.value == 3)
  }

  @Test("ObservableValue constant")
  func test_constant() {
    let observable = ObservableValue.constant(42)
    #expect(observable.value == 42)
  }

  @Test("ObservableValue dynamic member lookup")
  func test_dynamicMemberLookup() {
    struct TestStruct {
      let value: Int
      let text: String
    }

    let data = TestStruct(value: 42, text: "test")
    let observable = ObservableValue(data)

    #expect(observable.value.value == 42)
    #expect(observable.text == "test")
  }

  @Test("ObservableValue maintains identity")
  func test_identity() {
    let observable1 = ObservableValue(1)
    let observable2 = ObservableValue(1)

    #expect(observable1.id != observable2.id)
  }

  @Test("ObservableValue cleanup on deinit")
  func test_cleanup() async throws {
    let subject = PassthroughSubject<Int, Never>()
    var observable: ObservableValue<Int>? = ObservableValue(subject.eraseToAnyPublisher(), initial: 0)

    weak var weakObservable = observable
    #expect(weakObservable != nil)

    observable = nil
    #expect(weakObservable == nil)
  }

  @Test("Map ObservableValue")
  func map() async throws {
    let observable = ObservableValue(2)
    let mapped = observable.map { $0 * 3 }
    #expect(mapped.value == 6)

    let hasChanged = expectation(description: "Mapped value changed")
    let cancellable = mapped.observeChanges(to: \.value) { newValue in
      #expect(newValue == 12)
      hasChanged.fulfill()
    }
    observable.value = 4

    try await fulfillment(of: hasChanged)
    #expect(mapped.value == 12)
    _ = cancellable
  }
}
