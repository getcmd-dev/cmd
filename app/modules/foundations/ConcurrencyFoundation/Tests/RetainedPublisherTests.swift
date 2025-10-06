// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation
import Testing

// MARK: - RetainingSubscriptionTests

@MainActor
struct RetainedPublisherTests {
  @Test("sends values to the subscriber")
  func testSendValues() async throws {
    let upstream = CurrentValueSubject<Int, Never>(0)
    let publisher = RetainedPublisher<Int, Never>(upstream: upstream.eraseToAnyPublisher(), lifetime: AnyCancellable({ }))

    var i = 0
    let cancellable = publisher.sink { value in
      i += 1
      if i == 1 {
        #expect(value == 0)
      } else {
        #expect(value == 1)
      }
    }

    upstream.send(1)
    #expect(i == 2)
    _ = cancellable
  }

  @Test("The object is retained until the subscription is cancelled")
  func testRetentionUntilCancelled() async throws {
    let upstream = PassthroughSubject<Int, Never>()
    var publisher: RetainedPublisher<Int, Never>? = .init(upstream: upstream.eraseToAnyPublisher(), lifetime: AnyCancellable({ }))
    weak var referenceObserver: RetainedPublisher<Int, Never>? = publisher

    let cancellable = publisher?.sink { _ in }
    // After this point, the publisher should be retained by the subscription.
    publisher = nil
    upstream.send(1)
    #expect(referenceObserver != nil)

    cancellable?.cancel()
    #expect(referenceObserver == nil)
  }

  @Test("The object is retained until the subscription is deallocated")
  func testRetentionUntilDeinitialized() async throws {
    let upstream = PassthroughSubject<Int, Never>()
    var publisher: RetainedPublisher<Int, Never>? = .init(upstream: upstream.eraseToAnyPublisher(), lifetime: AnyCancellable({ }))
    weak var referenceObserver: RetainedPublisher<Int, Never>? = publisher

    var cancellable = publisher?.sink { _ in }
    _ = cancellable
    // After this point, the publisher should be retained by the subscription.
    publisher = nil
    upstream.send(1)
    #expect(referenceObserver != nil)

    cancellable = nil
    #expect(referenceObserver == nil)
  }

}
