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
    let values = Atomic([Int]())

    let cancellable = observe(observable) { previousValue in
      let count = values.mutate {
        $0.append(previousValue)
        return $0.count
      }
      if count == 3 {
        updates.fulfill()
      }
    }
    defer { cancellable.cancel() }

    subject.send(1)
    subject.send(2)
    subject.send(3)

    try await fulfillment(of: [updates])
    #expect(values.value == [0, 1, 2])
    #expect(observable.value == 3)
  }

  @Test("ObservableValue updates from async stream")
  func test_streamUpdates() async throws {
    let (stream, continuation) = AsyncStream<Int>.makeStream()
    let observable = ObservableValue(initial: 0, updates: stream)

    #expect(observable.value == 0)

    let updates = expectation(description: "Updates received")
    let values = Atomic([Int]())

    let cancellable = observe(observable) { value in
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
    #expect(values.value == [0, 1, 2])
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
}

// MARK: - Helpers

extension ObservableValueTests {
  /// Observes changes to the ObservableValue.
  /// - Parameters:
  ///  - onChange: The closure to call when the value changes. It is called with the previous value.
  @MainActor
  private func observe<Value>(_ observable: ObservableValue<Value>, onChange: @escaping (Value) -> Void) -> AnyCancellable {
    let observeOnce: (@MainActor (@MainActor @escaping () -> Void) -> Void) = { @MainActor callback in
      withObservationTracking {
        _ = observable.value
      } onChange: {
        MainActor.assumeIsolated {
          callback()
        }
      }
    }

    let task = Task {
      var loop: (@MainActor () -> Void)?
      loop = {
        observeOnce {
          guard !Task.isCancelled else { return }
          onChange(observable.value)
          loop?()
        }
      }
      loop?()
    }

    return AnyCancellable {
      task.cancel()
    }
  }
}
