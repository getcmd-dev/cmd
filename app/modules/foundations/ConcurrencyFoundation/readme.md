
# Concurrency Foundation

This library contains a few types that extend Combine's functionalities and help work across Combine, Observation and Swift concurrency:
- `Atomic`: allows for thread safe access and mutation to a wrapped value. Most mutable values can be wrapped in an `Atomic` to be made Sendable.
- `BroadcastedStream`: like `AsyncStream`, but can be subscribed to by several subscribers.
- `CurrentValueStream`: `AsyncStream` meets `CurrentValueSubject`.
- `ObservableValue`: make the wrapped value Observable.
- `ReadonlyCurrentValueSubject`: a `CurrentValueSubject` that is read only (ie a Publisher with a current value).
- `ReplaceableTaskQueue`: a queue of tasks that serially executes them, and discards any non started task when a new one is queued. This is an alternative to debouncing that doesn't add a delay, and might work better with tasks that don't cancel well.
- `RetainingSubscription`: a subscription to a publisher that will retain a given object that would otherwise be discarded.
