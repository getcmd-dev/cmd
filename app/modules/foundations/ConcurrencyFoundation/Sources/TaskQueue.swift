// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine

// MARK: - TaskQueue

/// A queue that manages asynchronous tasks and executes them serially (FIFO).
///
/// `TaskQueue` executes tasks sequentially with the following behavior:
/// - If no task is running, the queued task starts immediately
/// - If a task is running, new tasks are added to the queue
/// - Tasks are executed in the order they were added (FIFO)
/// - All tasks will eventually execute, unlike `ReplaceableTaskQueue` which may discard pending tasks
///
/// Example usage:
/// ```swift
/// let queue = TaskQueue<String>()
/// queue.sink { result in
///     print("Completed task with result: \(result)")
/// }
///
/// // If these are queued while no task is running, task1 starts immediately
/// queue.queue { await task1() } // This will complete first
/// queue.queue { await task2() } // This will execute after task1 completes
/// queue.queue { await task3() } // This will execute after task2 completes
/// ```
///
/// The queue implements the `Publisher` protocol, allowing you to subscribe to task results
/// using Combine's subscription methods.
public final class TaskQueue<Output: Sendable, Failure: Error>: Sendable {

  public init() { }

  private struct State: Sendable {
    var isExecuting = false
    var taskQueue: [@Sendable () async throws -> Output] = []
  }

  private let publisher = CurrentValueSubject<Output?, Failure>(nil)

  private let state = Atomic<State>(State())

  @discardableResult
  private func queue(task: @escaping @Sendable () async throws(Failure) -> Output) -> Future<Output, Failure> {
    let (future, continuation) = Future<Output, Failure>.make()
    state.mutate { state in
      state.taskQueue.append {
        do throws(Failure) {
          let output = try await task()
          continuation(.success(output))
          return output
        } catch {
          continuation(.failure(error))
          throw error
        }
      }
    }
    dequeue()
    return future
  }

  private func dequeue(clearingCurrentTask: Bool = false) {
    let task: (@Sendable () async throws -> Output)? = state.mutate { state in
      if !state.isExecuting || clearingCurrentTask, let nextTask = state.taskQueue.first {
        state.taskQueue.removeFirst()
        state.isExecuting = true
        return nextTask
      } else if clearingCurrentTask {
        state.isExecuting = false
      }
      return nil
    }

    if let task {
      Task { [weak self] in
        do {
          let output = try await task()
          self?.publisher.send(output)
          self?.dequeue(clearingCurrentTask: true)
        } catch {
          // for now, do nothing with the error.
          self?.dequeue(clearingCurrentTask: true)
        }
      }
    }
  }

  private func wrap(_ task: @escaping @Sendable () async throws -> Output) -> @Sendable () async -> Result<Output, Error> {
    {
      do {
        return try await .success(task())
      } catch {
        return .failure(error)
      }
    }
  }

  private func wrap(_ task: @escaping @Sendable () async -> Output) -> @Sendable () async -> Result<Output, Never> {
    {
      await .success(task())
    }
  }
}

extension TaskQueue where Failure: Error {
  public func queueAndAwait(_ task: @escaping @Sendable () async throws(Failure) -> Output) async throws(Failure) -> Output {
    let future = queue(task: task)
    do {
      return try await future.value
    } catch let error as Failure {
      throw error
    } catch {
      // Unclear why Combine has
      // `final public var value: Output { get async throws }`
      // instead of
      // final public var value: Output { get async throws(Failure) }
      fatalError("Unexpected error type: \(error)")
    }
  }

  @discardableResult
  public func queue(_ task: @escaping @Sendable () async throws(Failure) -> Output) -> Future<Output, Failure> {
    queue(task: task)
  }
}

extension TaskQueue where Failure == Never {
  public func queueAndAwait(_ task: @escaping @Sendable () async -> Output) async -> Output {
    let future = queue(task: task)
    return await future.value
  }

  @discardableResult
  public func queue(_ task: @escaping @Sendable () async -> Output) -> Future<Output, Failure> {
    queue(task: task)
  }
}

extension TaskQueue: Publisher {
  public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    publisher.eraseToAnyPublisher().compactMap(\.self).receive(subscriber: subscriber)
  }
}
