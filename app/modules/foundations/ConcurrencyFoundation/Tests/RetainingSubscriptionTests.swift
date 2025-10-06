// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation
import Testing

// MARK: - RetainingSubscriptionTests

@MainActor
struct RetainingSubscriptionTests {
  @Test("sends values to the subscriber")
  func testSendValues() async throws {
    let publisher = TestPublisher()

    var i = 0
    let cancellable = publisher.sink { value in
      i += 1
      if i == 1 {
        #expect(value == 0)
      } else {
        #expect(value == 1)
      }
    }

    publisher.send(1)
    #expect(i == 2)
    _ = cancellable
  }

  @Test("The object is retained until the subscription is cancelled")
  func testRetentionUntilCancelled() async throws {
    var publisher: TestPublisher? = TestPublisher()
    weak var referenceObserver: TestPublisher? = publisher

    let cancellable = publisher?.sink { _ in }
    // After this point, the publisher should be retained by the subscription.
    publisher = nil
    publisher?.send(1)
    #expect(referenceObserver != nil)

    cancellable?.cancel()
    #expect(referenceObserver == nil)
  }

  @Test("The object is retained until the subscription is deallocated")
  func testRetentionUntilDeinitialized() async throws {
    var publisher: TestPublisher? = TestPublisher()
    weak var referenceObserver: TestPublisher? = publisher

    var cancellable = publisher?.sink { _ in }
    _ = cancellable
    // After this point, the publisher should be retained by the subscription.
    publisher = nil
    publisher?.send(1)
    #expect(referenceObserver != nil)

    cancellable = nil
    #expect(referenceObserver == nil)
  }

  @Test @MainActor
  func test_deinit() {
    var test: Lifetime? = Lifetime(onDeinit: { })
    let release = createRelease(for: test)
    test = nil
    DispatchQueue.global(qos: .background).async {
      release.value()
    }
  }

  private func createRelease(for value: Lifetime?) -> Atomic<@Sendable () -> Void> {
    let release = Atomic<@Sendable () -> Void>({ })
    release.set(to: {
      _ = value
      release.set(to: { })
    })
    return release
  }

}

// MARK: - TestPublisher

private final class TestPublisher: Publisher {

  typealias Output = Int

  typealias Failure = Never

  func send(_ value: Int) {
    self.value.send(value)
  }

  func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Int == S.Input {
    subscriber.receive(subscription: RetainingSubscription(
      retained: self,
      publisher: value.eraseToAnyPublisher(),
      subscriber: subscriber))
  }

  private let value = CurrentValueSubject<Int, Never>(0)

}
