// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import SwiftTesting
import Testing
@testable import ConcurrencyFoundation

struct FutureExtensionTests {

  @Test("Sendable init creates future that resolves successfully")
  func test_sendableInit_success() async throws {
    let future = Future<Int, Never> { promise in
      promise(.success(42))
    }

    let value = await future.value
    #expect(value == 42)
  }

  @Test("Sendable init creates future that resolves with error")
  func test_sendableInit_failure() async throws {
    enum TestError: Error {
      case failed
    }

    let future = Future<Int, TestError> { promise in
      promise(.failure(.failed))
    }

    do {
      _ = try await future.value
      Issue.record("Expected error to be thrown")
    } catch {
      #expect(error as? TestError == .failed)
    }
  }

  @Test("make() creates future and continuation")
  func test_make() async throws {
    let (future, continuation) = Future<Int, Never>.make()

    Task {
      try? await Task.sleep(nanoseconds: 10_000_000)
      continuation(.success(100))
    }

    let value = await future.value
    #expect(value == 100)
  }

  @Test("make() continuation resolves with error")
  func test_make_error() async throws {
    enum TestError: Error {
      case testFailed
    }

    let (future, continuation) = Future<Int, TestError>.make()

    Task {
      continuation(.failure(.testFailed))
    }

    do {
      _ = try await future.value
      Issue.record("Expected error to be thrown")
    } catch {
      #expect(error as? TestError == .testFailed)
    }
  }

  @Test("makeRacingContinuations() first call wins")
  func test_makeRacingContinuations_firstWins() async throws {
    let (future, continuation) = Future<Int, Never>.makeRacingContinuations()

    continuation.resume(returning: 1)
    continuation.resume(returning: 2)
    continuation.resume(returning: 3)

    let value = await future.value
    #expect(value == 1)
  }

  @Test("makeRacingContinuations() with error")
  func test_makeRacingContinuations_error() async throws {
    enum TestError: Error {
      case first
      case second
    }

    let (future, continuation) = Future<Int, TestError>.makeRacingContinuations()

    continuation.resume(throwing: .first)
    continuation.resume(returning: 100)
    continuation.resume(throwing: .second)

    do {
      _ = try await future.value
      Issue.record("Expected error to be thrown")
    } catch {
      #expect(error as? TestError == .first)
    }
  }

  @Test("Just creates future with immediate value")
  func test_just() async throws {
    let future = Future<String, Never>.Just("immediate")

    let value = await future.value
    #expect(value == "immediate")
  }

  @Test("withRacedThrowingContinuation resolves successfully")
  func test_withRacedThrowingContinuation_success() async throws {
    let value: Int = try await withRacedThrowingContinuation { continuation in
      Task {
        try? await Task.sleep(nanoseconds: 10_000_000)
        continuation.resume(returning: 42)
      }
    }

    #expect(value == 42)
  }

  @Test("withRacedThrowingContinuation throws error")
  func test_withRacedThrowingContinuation_error() async throws {
    enum TestError: Error {
      case failed
    }

    do {
      let _: Int = try await withRacedThrowingContinuation { continuation in
        Task {
          continuation.resume(throwing: TestError.failed)
        }
      }
      Issue.record("Expected error to be thrown")
    } catch {
      #expect(error as? TestError == .failed)
    }
  }

  @Test("RacedContinuation resume with result success")
  func test_racedContinuation_resumeResult_success() async throws {
    let value: String = try await withRacedThrowingContinuation { continuation in
      Task {
        continuation.resume(.success("result"))
      }
    }

    #expect(value == "result")
  }

  @Test("RacedContinuation resume with result failure")
  func test_racedContinuation_resumeResult_failure() async throws {
    enum TestError: Error {
      case testCase
    }

    do {
      let _: Int = try await withRacedThrowingContinuation { continuation in
        Task {
          continuation.resume(.failure(TestError.testCase))
        }
      }
      Issue.record("Expected error to be thrown")
    } catch {
      #expect(error as? TestError == .testCase)
    }
  }

  @Test("RacedContinuation resume void")
  func test_racedContinuation_resumeVoid() async throws {
    let completed: Void = try await withRacedThrowingContinuation { (continuation: RacedContinuation<Void, Error>) in
      Task {
        continuation.resume()
      }
    }

    #expect(completed == ())
  }

  @Test("RacedContinuation timeout")
  func test_racedContinuation_timeout() async throws {
    do {
      let _: Int = try await withRacedThrowingContinuation { (continuation: RacedContinuation<Int, Error>) in
        continuation.timeout(afterNanoseconds: 10_000_000)
      }
      Issue.record("Expected timeout error to be thrown")
    } catch is TimeoutError {
      // Expected
    } catch {
      Issue.record("Expected CancellationError but got \(error)")
    }
  }

  @Test("RacedContinuation timeout can be overridden by early resume")
  func test_racedContinuation_timeout_overridden() async throws {
    let value: Int = try await withRacedThrowingContinuation { (continuation: RacedContinuation<Int, Error>) in
      continuation.timeout(afterNanoseconds: 100_000_000)
      continuation.resume(returning: 99)
    }

    #expect(value == 99)
  }

  @Test("Future with Combine sink")
  func test_future_combineIntegration() async throws {
    let (future, continuation) = Future<String, Never>.make()
    let completion = expectation(description: "Sink received value")
    var receivedValue: String?

    let cancellable = future.sink { value in
      receivedValue = value
      completion.fulfill()
    }
    defer { cancellable.cancel() }

    continuation(.success("test"))

    try await fulfillment(of: [completion])
    #expect(receivedValue == "test")
  }
}
