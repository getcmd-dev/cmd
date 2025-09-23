// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine

/// A queue that manages asynchronous tasks where new tasks replace any pending task.
///
/// `ReplaceableTaskQueue` executes tasks sequentially with the following behavior:
/// - If no task is running, the queued task starts immediately
/// - If a task is running, any previously pending task is replaced by the newly queued task
/// - Currently executing tasks run to completion and are not interrupted
///
/// Example usage:
/// ```swift
/// let queue = ReplaceableTaskQueue<String>()
/// queue.sink { result in
///     print("Completed task with result: \(result)")
/// }
///
/// // If these are queued while no task is running, task1 starts immediately
/// queue.queue { await task1() } // This will complete
/// queue.queue { await task2() } // This replaces any pending task
/// queue.queue { await task3() } // This replaces task2, will run after task1 finishes
/// ```
///
/// The queue implements the `Publisher` protocol, allowing you to subscribe to task results
/// using Combine's subscription methods.
public final class ReplaceableTaskQueue<Output: Sendable>: Sendable, Publisher {

  public init() { }

  public typealias Failure = Never

  public typealias QueuedTask = @Sendable () async throws -> Output

  public func receive<S>(subscriber: S) where S: Subscriber, S.Input == Output, S.Failure == Never {
    publisher.compactMap(\.self).receive(subscriber: subscriber)
  }

  public func queue(_ task: @escaping QueuedTask) {
    state.mutate { $0.nextTask = task }
    dequeue()
  }

  /// Waits until the queue has no running or pending tasks.
  ///
  /// This function is useful for synchronization in tests or when you need to ensure
  /// all tasks have completed before proceeding.
  ///
  /// Example usage:
  /// ```swift
  /// let queue = ReplaceableTaskQueue<String>()
  /// queue.queue { await task1() }
  /// queue.queue { await task2() }
  ///
  /// // Wait until all tasks have completed
  /// await queue.waitForIdle()
  /// ```
  public func waitForIdle() async {
    let (future, continuation) = Future<Void, Never>.make()
    let needToWait = state.mutate { state in
      if state.currentTask == nil, state.nextTask == nil {
        return false
      } else {
        state.onIdle.append { continuation(.success(())) }
        return true
      }
    }
    if !needToWait {
      continuation(.success(()))
    }
    await future.value
  }

  private struct State: Sendable {
    var currentTask: QueuedTask?
    var nextTask: QueuedTask?
    var onIdle: [@Sendable () -> Void] = []
  }

  private let publisher = CurrentValueSubject<Output?, Failure>(nil)

  private let state = Atomic<State>(State())

  private func dequeue(clearingCurrentTask: Bool = false) {
    let (taskToExecute, onIdle): (QueuedTask?, [@Sendable () -> Void]?) = state.mutate { state in
      if
        state.currentTask == nil || clearingCurrentTask,
        let nextTask = state.nextTask
      {
        state.nextTask = nil
        state.currentTask = nextTask
        return (nextTask, nil)
      } else if clearingCurrentTask {
        state.currentTask = nil
      }
      if state.currentTask == nil {
        let onIdle = state.onIdle
        state.onIdle = []
        return (nil, onIdle)
      }
      return (nil, nil)
    }

    if let taskToExecute {
      Task { [weak self] in
        do {
          let output = try await taskToExecute()
          guard let self else { return }
          publisher.send(output)
          dequeue(clearingCurrentTask: true)
        } catch {
          // for now, do nothing with the error.
          self?.dequeue(clearingCurrentTask: true)
        }
      }
    }
    onIdle?.forEach { $0() }
  }

}
