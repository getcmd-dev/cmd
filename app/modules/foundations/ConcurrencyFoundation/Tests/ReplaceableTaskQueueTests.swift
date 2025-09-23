// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Combine
import ConcurrencyFoundation
import SwiftTesting
import Testing

struct ReplaceableTaskQueueTests {

  @Test("Executes a single task")
  func test_singleTask() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let completion = expectation(description: "Task completed")
    var results = [Int]()

    let cancellable = queue.sink { value in
      results.append(value)
      completion.fulfill()
    }
    defer { cancellable.cancel() }

    queue.queue { 42 }

    try await fulfillment(of: [completion])
    #expect(results == [42])
  }

  @Test("Currently running task completes even when new task is queued")
  func test_runningTaskCompletes() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let firstTaskStarted = expectation(description: "First task started")
    let firstTaskReady = expectation(description: "First task ready to complete")
    let firstTaskCompleted = expectation(description: "First task completed")
    let secondTaskCompleted = expectation(description: "Second task completed")
    var results = [Int]()

    let cancellable = queue.sink { value in
      results.append(value)
      if results.count == 1 {
        firstTaskCompleted.fulfill()
      } else if results.count == 2 {
        secondTaskCompleted.fulfill()
      }
    }
    defer { cancellable.cancel() }

    // Queue a task that we can control completion of
    queue.queue {
      firstTaskStarted.fulfill()
      do {
        try await fulfillment(of: [firstTaskReady])
      } catch {
        Issue.record(error)
      }
      return 1
    }

    // Wait for first task to start
    try await fulfillment(of: [firstTaskStarted])

    // Queue another task while first is running
    queue.queue { 2 }

    // Allow first task to complete
    firstTaskReady.fulfill()

    try await fulfillment(of: [firstTaskCompleted, secondTaskCompleted])
    #expect(results == [1, 2])
  }

  @Test("New task replaces pending task")
  func test_replacePendingTask() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let firstTaskStarted = expectation(description: "First task started")
    let firstTaskReady = expectation(description: "First task ready to complete")
    let completion = expectation(description: "All tasks completed")
    var results = [Int]()

    let cancellable = queue.sink { value in
      results.append(value)
      if results.count == 2 {
        completion.fulfill()
      }
    }
    defer { cancellable.cancel() }

    // Queue a task that we can control completion of
    queue.queue {
      firstTaskStarted.fulfill()
      do {
        try await fulfillment(of: [firstTaskReady])
      } catch {
        Issue.record(error)
      }
      return 1
    }

    try await fulfillment(of: [firstTaskStarted])

    // Queue two tasks while first is running - the second should replace the first
    queue.queue { 2 } // This should be replaced
    queue.queue { 3 } // This should run after task 1

    // Allow first task to complete
    firstTaskReady.fulfill()

    try await fulfillment(of: [completion])
    #expect(results == [1, 3], "Should receive results from first and third task only")
  }

  @Test("Tasks execute sequentially")
  func test_sequentialExecution() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let firstTaskStarted = expectation(description: "First task started")
    let secondTaskStarted = expectation(description: "Second task started")
    let completion = expectation(description: "All tasks completed")
    var results = [Int]()
    let executionOrder = Atomic<[Int]>([])

    let cancellable = queue.sink { value in
      results.append(value)
      if results.count == 2 {
        completion.fulfill()
      }
    }
    defer { cancellable.cancel() }

    queue.queue {
      firstTaskStarted.fulfill()
      executionOrder.mutate { $0.append(1) }
      return 1
    }

    queue.queue {
      secondTaskStarted.fulfill()
      executionOrder.mutate { $0.append(2) }
      return 2
    }

    try await fulfillment(of: [firstTaskStarted, secondTaskStarted, completion])
    #expect(executionOrder.value == [1, 2], "Tasks should execute in order")
    #expect(results == [1, 2], "Results should be in order")
  }

  @Test("Continues processing after task failure")
  func test_continuesAfterTaskFailure() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let completion = expectation(description: "Successful task completed")
    var results = [Int]()

    let cancellable = queue.sink { value in
      results.append(value)
      completion.fulfill()
    }
    defer { cancellable.cancel() }

    // First task throws an error
    queue.queue {
      throw NSError(domain: "test", code: 1)
    }

    // Second task should still execute
    queue.queue {
      42
    }

    try await fulfillment(of: [completion])
    #expect(results == [42], "Second task should execute after first task fails")
  }

  @Test("Handles failure in the middle of multiple tasks")
  func test_handlesMiddleTaskFailure() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let completion = expectation(description: "All tasks completed")
    var results = [Int]()

    let cancellable = queue.sink { value in
      results.append(value)
      if results.count == 2 {
        completion.fulfill()
      }
    }
    defer { cancellable.cancel() }

    // First task succeeds
    queue.queue { 1 }

    // Second task fails
    queue.queue {
      throw NSError(domain: "test", code: 1)
    }

    // Third task should still execute
    queue.queue { 3 }

    try await fulfillment(of: [completion])
    #expect(results == [1, 3], "First and third tasks should execute successfully")
  }

  @Test("Replace task behavior works after failure")
  func test_replaceTaskAfterFailure() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let firstTaskStarted = expectation(description: "First task started")
    let firstTaskReady = expectation(description: "First task ready to complete")
    let completion = expectation(description: "All tasks completed")
    var results = [Int]()

    let cancellable = queue.sink { value in
      results.append(value)
      if results.count == 1 {
        completion.fulfill()
      }
    }
    defer { cancellable.cancel() }

    // Queue a task that we can control completion of
    queue.queue {
      firstTaskStarted.fulfill()
      do {
        try await fulfillment(of: [firstTaskReady])
      } catch {
        Issue.record(error)
      }
      throw NSError(domain: "test", code: 1)
    }

    try await fulfillment(of: [firstTaskStarted])

    // Queue two tasks while first is running
    queue.queue { 2 } // This should be replaced
    queue.queue { 3 } // This should run after the failing task

    // Allow first task to complete (with failure)
    firstTaskReady.fulfill()

    try await fulfillment(of: [completion])
    #expect(results == [3], "Only the replacing task should execute after failure")
  }

  @Test("waitForIdle returns immediately when queue is already idle")
  func test_waitForIdleImmediate() async throws {
    let queue = ReplaceableTaskQueue<Int>()

    // Measure time to verify it returns quickly
    let startTime = Date()
    await queue.waitForIdle()
    let elapsedTime = Date().timeIntervalSince(startTime)

    #expect(elapsedTime < 0.1, "Should return almost immediately when queue is idle")
  }

  @Test("waitForIdle waits until all tasks complete")
  func test_waitForIdleWithTasks() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let taskStarted = expectation(description: "Task started")
    let taskReady = expectation(description: "Task ready to complete")
    let taskCompletedExpectation = expectation(description: "Task completed")
    let waitCompletedExpectation = expectation(description: "Wait completed")

    // Queue a task that we can control completion of
    queue.queue {
      taskStarted.fulfill()
      do {
        try await fulfillment(of: [taskReady])
      } catch {
        Issue.record(error)
      }
      taskCompletedExpectation.fulfill()
      return 1
    }

    // Wait for task to start
    try await fulfillment(of: [taskStarted])

    // Start waiting for idle in a separate task
    Task {
      await queue.waitForIdle()
      waitCompletedExpectation.fulfill()
    }

    #expect(waitCompletedExpectation.isFulfilled == false)

    // Allow task to complete
    taskReady.fulfill()

    // Now waitForIdle should complete
    try await fulfillment(of: [taskCompletedExpectation, waitCompletedExpectation], timeout: 1.0)
  }

  @Test("waitForIdle works with multiple sequential tasks")
  func test_waitForIdleWithMultipleTasks() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let receivedValues = Atomic<[Int]>([])
    let cancellable = queue.sink { @Sendable value in
      receivedValues.mutate { $0.append(value) }
    }

    // Queue multiple tasks
    queue.queue {
      try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
      return 1
    }
    queue.queue {
      try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
      return 2
    }
    queue.queue {
      try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
      return 3
    }

    // Wait for all tasks to complete
    await queue.waitForIdle()

    // The second task should be replaced by the third task
    #expect(receivedValues.value == [1, 3])
    _ = cancellable
  }

  @Test("waitForIdle works after task failure")
  func test_waitForIdleAfterFailure() async throws {
    let queue = ReplaceableTaskQueue<Int>()
    let completedTasks = Atomic<[Int]>([])
    let successTaskCompleted = expectation(description: "Success task completed")

    // Queue a task that will fail
    queue.queue {
      try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
      throw NSError(domain: "test", code: 1)
    }

    // Queue a task that will succeed
    queue.queue {
      try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
      completedTasks.mutate { $0.append(1) }
      successTaskCompleted.fulfill()
      return 1
    }

    // Wait for all tasks to complete
    await queue.waitForIdle()

    // Verify the second task completed despite the first task's failure
    try await fulfillment(of: [successTaskCompleted])
    #expect(completedTasks.value == [1], "Second task should complete after first task fails")
  }
}
