// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import SwiftTesting
import Testing
@testable import ConcurrencyFoundation

// MARK: - ObservableObjectBoxTests

@MainActor
struct ObservableObjectBoxTests {

  @MainActor @Suite("ObservableObject initialized from a Publisher")
  struct PublisherTests {
    @Test("ObservableObjectBox initializes with current value")
    func test_initialization() {
      let subject = CurrentValueSubject<Int, Never>(42)
      let sut = ObservableObjectBox(from: subject.readonly())

      #expect(sut.wrappedValue == 42)
    }

    @Test("ObservableObjectBox updates from subject")
    func test_updates() async throws {
      let subject = CurrentValueSubject<Int, Never>(0)
      let sut = ObservableObjectBox(from: subject.readonly())

      #expect(sut.wrappedValue == 0)

      let valuesReceivedInWillChange = Atomic<[Int]>([])
      let updates = expectation(description: "Updates received")
      let cancellable = sut.$wrappedValue.sink { @Sendable value in
        valuesReceivedInWillChange.mutate { $0.append(value) }
        if value == 3 {
          updates.fulfillAtMostOnce()
        }
      }

      subject.send(1)
      subject.send(2)
      subject.send(3)

      try await fulfillment(of: [updates])
      #expect(valuesReceivedInWillChange.value == [0, 1, 2, 3])
      #expect(sut.wrappedValue == 3)
      _ = cancellable
    }

    @Test("ObservableObjectBox asObservableObjectBox extension")
    func test_asObservableObjectBoxExtension() async {
      let subject = CurrentValueSubject<String, Never>("hello")
      let sut = subject.readonly().asObservableObjectBox()

      #expect(sut.wrappedValue == "hello")

      subject.send("world")
      #expect(sut.wrappedValue == "world")
    }

    @Test("ObservableObjectBox handles rapid updates")
    func test_rapidUpdates() async throws {
      let subject = CurrentValueSubject<Int, Never>(0)
      let sut = ObservableObjectBox(from: subject.readonly())

      let valuesReceivedInWillChange = Atomic<[Int]>([])
      let updates = expectation(description: "Final update received")
      let cancellable = sut.$wrappedValue.sink { @Sendable value in
        valuesReceivedInWillChange.mutate { $0.append(value) }
        if value == 100 {
          updates.fulfillAtMostOnce()
        }
      }

      for i in 1...100 {
        subject.send(i)
      }

      try await fulfillment(of: [updates])
      #expect(sut.wrappedValue == 100)
      #expect(valuesReceivedInWillChange.value == Array(0..<101))
      _ = cancellable
    }

    @Test("ObservableObjectBox with struct")
    func test_withStruct() async throws {
      struct TestData: Sendable, Equatable {
        let value: Int
        let text: String
      }

      let subject = CurrentValueSubject<TestData, Never>(TestData(value: 1, text: "first"))
      let sut = ObservableObjectBox(from: subject.readonly())

      #expect(sut.wrappedValue.value == 1)
      #expect(sut.wrappedValue.text == "first")

      let updates = expectation(description: "Update received")
      let cancellable = sut.$wrappedValue.sink { @Sendable value in
        if value.text == "second" {
          updates.fulfillAtMostOnce()
        }
      }

      subject.send(TestData(value: 2, text: "second"))

      try await fulfillment(of: [updates])
      #expect(sut.wrappedValue.value == 2)
      #expect(sut.wrappedValue.text == "second")
      _ = cancellable
    }

    @Test("ObservableObjectBox cleanup on deinit")
    func test_cleanup() async throws {
      let hasDeinitialized = expectation(description: "Has deinitialized")
      var subject: CurrentValueSubject<AnyCancellable, Never>? = .init(AnyCancellable {
        hasDeinitialized.fulfill()
      })
      weak var weakSubject: CurrentValueSubject<AnyCancellable, Never>? = subject

      var sut: ObservableObjectBox<AnyCancellable>? = try ObservableObjectBox(from: #require(subject).readonly())
      _ = sut
      #expect(hasDeinitialized.isFulfilled == false)

      sut = nil
      subject = nil
      try await fulfillment(of: hasDeinitialized)
      #expect(weakSubject == nil)
    }

    @Test("ObservableObjectBox thread safety")
    func test_threadSafety() async throws {
      let subject = CurrentValueSubject<Int, Never>(0)
      let sut = ObservableObjectBox(from: subject.readonly())

      let didReadManyTimes = expectation(description: "Did read many times")
      let didReceiveAllUpdates = expectation(description: "Did receive all updates")

      let updatesCount = Atomic(0)
      let cancellable = sut.$wrappedValue.sink { @Sendable value in
        let count = updatesCount.increment()
        if count == 50 {
          didReceiveAllUpdates.fulfill()
        }
      }

      Task.detached {
        for i in 1...50 {
          subject.send(i)
          try? await Task.sleep(nanoseconds: 1_000_000)
        }
      }

      Task {
        for _ in 1...50 {
          _ = sut.wrappedValue
          try? await Task.sleep(nanoseconds: 1_000_000)
        }
        didReadManyTimes.fulfill()
      }

      try await fulfillment(of: [didReadManyTimes, didReceiveAllUpdates])
      #expect(sut.wrappedValue == 50)
      _ = cancellable
    }
  }

  @MainActor
  @Suite("ObservableObject initialized from a value")
  struct ValueTests {
    @Test("ObservableObjectBox initializes with current value")
    func test_initialization() {
      let sut = ObservableObjectBox(42)

      #expect(sut.wrappedValue == 42)
    }

    @Test("ObservableObjectBox updates from subject")
    func test_updates() async throws {
      let sut = ObservableObjectBox(0)

      #expect(sut.wrappedValue == 0)

      let valuesReceivedInWillChange = Atomic<[Int]>([])
      let updates = expectation(description: "Updates received")
      let cancellable = sut.$wrappedValue.sink { @Sendable value in
        valuesReceivedInWillChange.mutate { $0.append(value) }
        if value == 3 {
          updates.fulfillAtMostOnce()
        }
      }

      sut.wrappedValue = 1
      sut.wrappedValue = 2
      sut.wrappedValue = 3

      try await fulfillment(of: [updates])
      #expect(valuesReceivedInWillChange.value == [0, 1, 2, 3])
      #expect(sut.wrappedValue == 3)
      _ = cancellable
    }

    @Test("ObservableObjectBox handles rapid updates")
    func test_rapidUpdates() async throws {
      let sut = ObservableObjectBox(0)

      let valuesReceivedInWillChange = Atomic<[Int]>([])
      let updates = expectation(description: "Final update received")
      let cancellable = sut.$wrappedValue.sink { @Sendable value in
        valuesReceivedInWillChange.mutate { $0.append(value) }
        if value == 100 {
          updates.fulfillAtMostOnce()
        }
      }

      for i in 1...100 {
        sut.wrappedValue = i
      }

      try await fulfillment(of: [updates])
      #expect(sut.wrappedValue == 100)
      #expect(valuesReceivedInWillChange.value == Array(0..<101))
      _ = cancellable
    }

    @Test("ObservableObjectBox with struct")
    func test_withStruct() async throws {
      struct TestData: Sendable, Equatable {
        let value: Int
        let text: String
      }

      let sut = ObservableObjectBox(TestData(value: 1, text: "first"))

      #expect(sut.wrappedValue.value == 1)
      #expect(sut.wrappedValue.text == "first")

      let updates = expectation(description: "Update received")
      let cancellable = sut.$wrappedValue.sink { @Sendable value in
        if value.text == "second" {
          updates.fulfillAtMostOnce()
        }
      }

      sut.wrappedValue = TestData(value: 2, text: "second")

      try await fulfillment(of: [updates])
      #expect(sut.wrappedValue.value == 2)
      #expect(sut.wrappedValue.text == "second")
      _ = cancellable
    }

    @Test("ObservableObjectBox thread safety")
    func test_threadSafety() async throws {
      let sut = ObservableObjectBox(0)

      let didReadManyTimes = expectation(description: "Did read many times")
      let didReceiveAllUpdates = expectation(description: "Did receive all updates")

      let updatesCount = Atomic(0)
      let cancellable = sut.$wrappedValue.sink { @Sendable value in
        let count = updatesCount.increment()
        if count == 50 {
          didReceiveAllUpdates.fulfill()
        }
      }

      Task {
        for i in 1...50 {
          sut.wrappedValue = i
          try? await Task.sleep(nanoseconds: 1_000_000)
        }
      }

      Task {
        for _ in 1...50 {
          _ = sut.wrappedValue
          try? await Task.sleep(nanoseconds: 1_000_000)
        }
        didReadManyTimes.fulfill()
      }

      try await fulfillment(of: [didReadManyTimes, didReceiveAllUpdates])
      #expect(sut.wrappedValue == 50)
      _ = cancellable
    }
  }
}
