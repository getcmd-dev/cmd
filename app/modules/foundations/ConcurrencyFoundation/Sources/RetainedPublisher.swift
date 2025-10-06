// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

//
//  RetainedPublisher.swift
//  Packages
//
//  Created by Guigui on 10/4/25.
//
import Combine

// MARK: - RetainedPublisher

/// A publisher that is retained by its active subscriptions, until they are deallocated or cancelled.
/// - Parameters:
///   - upstream: The wrapped publisher that publishes values to subscribers.
///   - lifetime: An optional object that is retained for the lifetime of the publisher.
public class RetainedPublisher<Output, Failure: Error>: Publisher {
  public init(upstream: AnyPublisher<Output, Failure>, lifetime: AnyObject? = nil) {
    self.upstream = upstream
    self.lifetime = lifetime
  }

  public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    _ = RetainingSubscription(
      retained: self,
      publisher: upstream,
      subscriber: subscriber,
      preReceiveHook: { subscription in subscriber.receive(subscription: subscription) })
  }

  private let upstream: AnyPublisher<Output, Failure>
  private let lifetime: AnyObject?

}

extension Publisher {
  public func retaining(_ object: some AnyObject) -> AnyPublisher<Output, Failure> {
    RetainedPublisher(upstream: eraseToAnyPublisher(), lifetime: object)
      .eraseToAnyPublisher()
  }
}
