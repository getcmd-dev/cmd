// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
@testable import ConcurrencyFoundation

import Foundation
import Observation
import SwiftTesting
import Testing

// MARK: - ObservableHelpersTests

enum ObservableHelpersTests {
  struct DidSetTests {
    @MainActor @Test("Is called once with the new value")
    func test_didSet_isCalledWithNewValue() async throws {
      // given
      let sut = ObservableValue(int: 1)
      let receivedValues = Atomic<[Int]>([])
      let cancellable: Cancellable? = sut.didSet(\.int, perform: { newValue in
        receivedValues.mutate { $0.append(newValue) }
      })

      // when
      sut.int = 2
      await nextTick()

      // then
      #expect(receivedValues.value == [2])

      // clean up
      _ = cancellable
    }

    @MainActor @Test("Is not called when cancelled")
    func test_didSet_isNotCalledWhenCancelled() async throws {
      // given
      let sut = ObservableValue(int: 1)
      let receivedValues = Atomic<[Int]>([])
      var cancellable: Cancellable? = sut.didSet(\.int, perform: { newValue in
        Issue.record("didSet should not be called")
        receivedValues.mutate { $0.append(newValue) }
      })
      _ = cancellable

      // when
      cancellable = nil
      sut.int = 2
      await nextTick()

      // then
      #expect(receivedValues.value == [])
    }

    @MainActor @Test("Is called each time the value changes")
    func test_didSet_isEachTimeTheValueChanges() async throws {
      // given
      let receivedValues = Atomic<[Int]>([])
      let sut = ObservableValue(int: 1)
      let cancellable: Cancellable? = sut.didSet(\.int, perform: { newValue in
        receivedValues.mutate { $0.append(newValue) }
      })

      // when
      sut.int = 2
      await nextTick()
      sut.int = 3
      await nextTick()
      sut.int = 4
      await nextTick()

      // then
      #expect(receivedValues.value == [2, 3, 4])

      // clean up
      _ = cancellable
    }

    @MainActor @Test("Is not called when a non-observed property changes")
    func test_didSet_isNotCalledWhenNonObservedPropertyChanges() async throws {
      // given
      let sut = ObservableValue(int: 1)
      let receivedValues = Atomic<[Int]>([])
      let cancellable: Cancellable? = sut.didSet(\.int, perform: { newValue in
        Issue.record("didSet should not be called")
        receivedValues.mutate { $0.append(newValue) }
      })
      _ = cancellable

      // when
      sut.structValue.string = "foo"
      await nextTick()

      // then
      #expect(receivedValues.value == [])

      // clean up
      _ = cancellable
    }
  }

  struct ObserveChangesTests {
    @MainActor @Test("observeChanges is called once when the read attributes change")
    func test_observeChanges_isCalledOnceWhenTheReadAttributesChange() async throws {
      // given
      let sut = ObservableValue(int: 1)
      let receivedValues = Atomic<[Int]>([])
      let cancellable = sut.observeChanges(of: { value in MainActor.assumeIsolated { value.int } }) { newValue in
        receivedValues.mutate { $0.append(newValue) }
      }

      // when
      sut.int = 2
      await nextTick()

      // then
      #expect(receivedValues.value == [2])

      // clean up
      _ = cancellable
    }

    @MainActor @Test("observeChanges is called once when the nested read attributes change")
    func test_observeChanges_isCalledOnceWhenTheReadAttributesChange2() async throws {
      // given
      let sut = ObservableValue(int: 1)
      let receivedValues = Atomic<[Int]>([])
      let cancellable = sut
        .observeChanges(of: { value in
          MainActor.assumeIsolated { value.observableValues.reduce(into: 0) { $0 += $1.int } }
        }) { newValue in
          receivedValues.mutate { $0.append(newValue) }
        }

      // when
      sut.observableValues.append(ObservableValue(int: 1))
      await nextTick()
      let cl = ObservableValue(int: 1)
      sut.observableValues.append(cl)
      await nextTick()
      cl.int = 2
      await nextTick()

      // then
      #expect(receivedValues.value == [1, 2, 3])

      // clean up
      _ = cancellable
    }
  }
}

// MARK: - StructValue

private struct StructValue: Sendable {
  var string = ""
}

// MARK: - ClassValue

@MainActor
private final class ClassValue: Sendable {
  init(string: String = "", int: Int = 0) {
    self.string = string
    self.int = int
  }

  var string: String
  var int: Int

}

// MARK: - ObservableValue

@Observable @MainActor
private final class ObservableValue: Sendable {
  init(
    int: Int,
    structValue: StructValue = StructValue(),
    structValues: [StructValue] = [StructValue](),
    classValue: ClassValue = ClassValue(),
    classValues: [ClassValue] = [ClassValue](),
    observableValue: ObservableValue? = nil,
    observableValues: [ObservableValue] = [ObservableValue]())
  {
    self.int = int
    self.structValue = structValue
    self.structValues = structValues
    self.classValue = classValue
    self.classValues = classValues
    self.observableValue = observableValue
    self.observableValues = observableValues
  }

  var int = 0
  var structValue = StructValue()
  var structValues = [StructValue]()
  var classValue = ClassValue()
  var classValues = [ClassValue]()
  var observableValue: ObservableValue? = nil
  var observableValues = [ObservableValue]()

}

/// Helpers
private func nextTick() async {
  _ = await withCheckedContinuation { continuation in
    Task {
      await MainActor.run {
        continuation.resume(returning: ())
      }
    }
  }
}
