// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import MacroTesting
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import ThreadSafeMacro
import XCTest

/// Test for the `@Sendable` macro
final class ThreadSafeMacroIntegrationTests: XCTestCase {

  func testThreadSafeMacroWithAccessors() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
        var count: Int
      }
      """,
      expandedSource: """
        final class Example {
          var count: Int {
              get {
                  _internalState.value.count
              }
              set {
                  _ = _internalState.set(\\.count, to: newValue)
              }
          }

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
              var count: Int
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
        "ThreadSafeProperty": ThreadSafePropertyMacro.self,
        "ThreadSafeInitializer": ThreadSafeInitializerMacro.self,
      ])
  }

  func testSimpleInitializers() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
        var count: Int
        init(count: Int) {
          self.count = count
        }
      }
      """,
      expandedSource: """
        final class Example {
          var count: Int {
              get {
                  _internalState.value.count
              }
              set {
                  _ = _internalState.set(\\.count, to: newValue)
              }
          }
          init(count: Int) {
              var _count: Int
              _count = count
              self._internalState = Atomic<_InternalState>(_InternalState(count: _count))
          }

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
              var count: Int
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
        "ThreadSafeProperty": ThreadSafePropertyMacro.self,
        "ThreadSafeInitializer": ThreadSafeInitializerMacro.self,
      ])
  }

  func testInitializerWithOtherProperties() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
        var count: Int
        let foo: String

        convenience init(count: Int) {
          self.init(count: count, foo: "foo")
        }

        init(count: Int, foo: String) {
          self.count = count
          self.foo = foo
          self.setup()
        }

        func setup() {}
      }
      """,
      expandedSource: """
        final class Example {
          var count: Int {
              get {
                  _internalState.value.count
              }
              set {
                  _ = _internalState.set(\\.count, to: newValue)
              }
          }
          let foo: String

          convenience init(count: Int) {
            self.init(count: count, foo: "foo")
          }

          init(count: Int, foo: String) {
              var _count: Int
              _count = count
              self._internalState = Atomic<_InternalState>(_InternalState(count: _count))
              self.foo = foo
              self.setup()
          }

          func setup() {}

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
              var count: Int
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
        "ThreadSafeProperty": ThreadSafePropertyMacro.self,
        "ThreadSafeInitializer": ThreadSafeInitializerMacro.self,
      ])
  }

  func testThreadSafeMacroOnlyExpandsCorrectVar() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
        var count: Int
        let value: String
        var name: String { "name" }
      }
      """,
      expandedSource: """
        final class Example {
          var count: Int {
              get {
                  _internalState.value.count
              }
              set {
                  _ = _internalState.set(\\.count, to: newValue)
              }
          }
          let value: String
          var name: String { "name" }

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
              var count: Int
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
        "ThreadSafeProperty": ThreadSafePropertyMacro.self,
        "ThreadSafeInitializer": ThreadSafeInitializerMacro.self,
      ])
  }

  func testThreadSafeMacroWithInferedTypes() {
    assertMacroExpansion(
      """
      @ThreadSafe
      public final class Example {
        var count = 0
        var isActive = false
        init() {}
      }
      """,
      expandedSource: """
        public final class Example {
          var count {
              get {
                  _internalState.value.count
              }
              set {
                  _ = _internalState.set(\\.count, to: newValue)
              }
          }
          var isActive {
              get {
                  _internalState.value.isActive
              }
              set {
                  _ = _internalState.set(\\.isActive, to: newValue)
              }
          }
          init() {
              let _count: Int = 0
              let _isActive: Bool = false
              self._internalState = Atomic<_InternalState>(_InternalState(count: _count, isActive: _isActive))
          }

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
              var count: Int
              var isActive: Bool
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
        "ThreadSafeProperty": ThreadSafePropertyMacro.self,
        "ThreadSafeInitializer": ThreadSafeInitializerMacro.self,
      ])
  }

  func testThreadSafeMacro_handleComplexArraySyntax() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
          private var eventHandlers = [@Sendable (_ appEvent: AppEvent) async -> Bool]()
      }
      """,
      expandedSource: """
        final class Example {
            private var eventHandlers {
                get {
                    _internalState.value.eventHandlers
                }
                set {
                    _ = _internalState.set(\\.eventHandlers, to: newValue)
                }
            }

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
              var eventHandlers: [@Sendable (_ appEvent: AppEvent) async -> Bool]
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
        "ThreadSafeProperty": ThreadSafePropertyMacro.self,
        "ThreadSafeInitializer": ThreadSafeInitializerMacro.self,
      ])
  }

  func testThreadSafeMacro_noMutableProperties() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
          init(value: Int) {
            self.value = value
          }

          let value: Int
      }
      """,
      expandedSource: """
        final class Example {
            init(value: Int) {
                self._internalState = Atomic<_InternalState>(_InternalState())
                self.value = value
            }

            let value: Int

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
        "ThreadSafeProperty": ThreadSafePropertyMacro.self,
        "ThreadSafeInitializer": ThreadSafeInitializerMacro.self,
      ])
  }
}
