// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine

// MARK: - RetainingSubscription

/// A subscription that will retain a given object until it is cancelled.
///
/// This is particularly useful when working with a publisher that needs to be retained while it is subscribed to.
public final class RetainingSubscription<Output, Failure: Error>: Subscription {

  public init<S: Subscriber>(
    retained: AnyObject,
    publisher: any Publisher<Output, Failure>,
    subscriber: S,
    preReceiveHook: ((RetainingSubscription<Output, Failure>) -> Void)? = nil) where S.Input == Output, S.Failure == Failure
  {
    self.retained = retained
    preReceiveHook?(self)

    subjectCancellable = publisher.sink(receiveCompletion: { completion in
      subscriber.receive(completion: completion)
    }, receiveValue: { value in
      _ = subscriber.receive(value)
    })
  }

  /// The subscriber may signal demand.
  /// You could honor this in more complex publishers.
  public func request(_: Subscribers.Demand) {
    // Typically ignored or stored, depending on your publisher's requirements.
  }

  /// Cancel is called when the subscriber goes away or explicitly cancels.
  public func cancel() {
    // Break the strong references so everything can deinit
    subjectCancellable = nil
    retained = nil
  }

  private var retained: AnyObject?
  private var subjectCancellable: AnyCancellable?

}
