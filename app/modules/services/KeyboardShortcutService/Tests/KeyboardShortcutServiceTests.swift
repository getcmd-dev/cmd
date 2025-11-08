// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Dependencies
import DependenciesTestSupport
import Foundation
import KeyboardShortcutServiceInterface
import Testing
import ThreadSafe
import XcodeObserverServiceInterface
@testable import KeyboardShortcutService

// MARK: - KeyboardShortcutServiceTests

@Suite("KeyboardShortcutServiceTests", .dependencies { $0.setDefaultMockValues() })
struct KeyboardShortcutServiceTests {

  @Test("Registers shortcut and returns cancellable")
  func registerShortcut_returnsCancellable() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCalled = Atomic(false)

    // when
    let cancellable = sut.registerShortcut(
      keyCode: 0,
      modifierFlags: 0,
      activationCondition: .always,
      action: {
        actionCalled.mutate { $0 = true }
      })

    // then
    #expect(cancellable != nil)
  }

  @Test("Triggers shortcut when activation condition is .always")
  func processKeyEvent_triggersWhenConditionIsAlways() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCalled = Atomic(false)
    let keyCode: UInt16 = 42
    let modifierFlags: UInt = 1_048_576 // Command key

    _ = sut.registerShortcut(
      keyCode: keyCode,
      modifierFlags: modifierFlags,
      activationCondition: .always,
      action: {
        actionCalled.mutate { $0 = true }
      })

    // when
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCalled.value == true)
  }

  @Test("Triggers shortcut only when Xcode is active")
  func processKeyEvent_triggersOnlyWhenXcodeActive() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCallCount = Atomic(0)
    let keyCode: UInt16 = 42
    let modifierFlags: UInt = 1_048_576

    _ = sut.registerShortcut(
      keyCode: keyCode,
      modifierFlags: modifierFlags,
      activationCondition: .xcodeActive,
      action: {
        actionCallCount.mutate { $0 += 1 }
      })

    // when - Xcode is not active
    appsActivationStateSubject.send(.hostAppActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 0)

    // when - Xcode becomes active
    appsActivationStateSubject.send(.xcodeActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 1)
  }

  @Test("Triggers shortcut only when host app is active")
  func processKeyEvent_triggersOnlyWhenHostAppActive() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCallCount = Atomic(0)
    let keyCode: UInt16 = 42
    let modifierFlags: UInt = 1_048_576

    _ = sut.registerShortcut(
      keyCode: keyCode,
      modifierFlags: modifierFlags,
      activationCondition: .hostAppActive,
      action: {
        actionCallCount.mutate { $0 += 1 }
      })

    // when - Host app is not active
    appsActivationStateSubject.send(.xcodeActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 0)

    // when - Host app becomes active
    appsActivationStateSubject.send(.hostAppActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 1)
  }

  @Test("Triggers shortcut when either app is active")
  func processKeyEvent_triggersWhenEitherAppActive() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCallCount = Atomic(0)
    let keyCode: UInt16 = 42
    let modifierFlags: UInt = 1_048_576

    _ = sut.registerShortcut(
      keyCode: keyCode,
      modifierFlags: modifierFlags,
      activationCondition: .eitherActive,
      action: {
        actionCallCount.mutate { $0 += 1 }
      })

    // when - Neither active
    appsActivationStateSubject.send(.inactive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 0)

    // when - Xcode active
    appsActivationStateSubject.send(.xcodeActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 1)

    // when - Host app active
    appsActivationStateSubject.send(.hostAppActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 2)

    // when - Both active
    appsActivationStateSubject.send(.bothActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 3)
  }

  @Test("Triggers shortcut only when both apps are active")
  func processKeyEvent_triggersOnlyWhenBothAppsActive() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCallCount = Atomic(0)
    let keyCode: UInt16 = 42
    let modifierFlags: UInt = 1_048_576

    _ = sut.registerShortcut(
      keyCode: keyCode,
      modifierFlags: modifierFlags,
      activationCondition: .bothActive,
      action: {
        actionCallCount.mutate { $0 += 1 }
      })

    // when - Only Xcode active
    appsActivationStateSubject.send(.xcodeActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 0)

    // when - Only host app active
    appsActivationStateSubject.send(.hostAppActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 0)

    // when - Both active
    appsActivationStateSubject.send(.bothActive)
    await nextTick()
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value == 1)
  }

  @Test("Cancellable can be cancelled without error")
  func cancellable_canBeCancelled() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCallCount = Atomic(0)
    let keyCode: UInt16 = 42
    let modifierFlags: UInt = 1_048_576

    let cancellable = sut.registerShortcut(
      keyCode: keyCode,
      modifierFlags: modifierFlags,
      activationCondition: .always,
      action: {
        actionCallCount.mutate { $0 += 1 }
      })

    // when - Trigger before cancel
    await sut.processKeyEvent(keyCode: keyCode, modifierFlags: modifierFlags)
    await nextTick()

    // then
    #expect(actionCallCount.value >= 1)

    // when - Cancel
    cancellable.cancel()

    // then - No error should occur
    #expect(true)
  }

  @Test("Does not trigger shortcut with different key code")
  func processKeyEvent_doesNotTriggerWithDifferentKeyCode() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCalled = Atomic(false)

    _ = sut.registerShortcut(
      keyCode: 42,
      modifierFlags: 1_048_576,
      activationCondition: .always,
      action: {
        actionCalled.mutate { $0 = true }
      })

    // when - Different key code
    await sut.processKeyEvent(keyCode: 43, modifierFlags: 1_048_576)
    await nextTick()

    // then
    #expect(actionCalled.value == false)
  }

  @Test("Does not trigger shortcut with different modifier flags")
  func processKeyEvent_doesNotTriggerWithDifferentModifierFlags() async throws {
    // given
    let appsActivationStateSubject = CurrentValueSubject<AppsActivationState, Never>(.inactive)
    let sut = DefaultKeyboardShortcutService(
      appsActivationState: appsActivationStateSubject.eraseToAnyPublisher())

    let actionCalled = Atomic(false)

    _ = sut.registerShortcut(
      keyCode: 42,
      modifierFlags: 1_048_576, // Command
      activationCondition: .always,
      action: {
        actionCalled.mutate { $0 = true }
      })

    // when - Different modifier flags
    await sut.processKeyEvent(keyCode: 42, modifierFlags: 524_288) // Shift
    await nextTick()

    // then
    #expect(actionCalled.value == false)
  }
}

extension DependencyValues {
  fileprivate mutating func setDefaultMockValues() {
    // Add any default mock dependencies if needed
  }
}

private func nextTick() async {
  await Task.yield()
}
