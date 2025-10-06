// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import MacroTesting
import SwiftSyntaxMacrosTestSupport
import ThreadSafeMacro
import XCTest

/// Test for the `@Sendable` macro
final class ThreadSafeMacroTests: XCTestCase {

  func testThreadSafeMacroWithAccessors() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
        var count: Int = 1
      }
      """,
      expandedSource: """
        final class Example {
          @ThreadSafeProperty
          var count: Int = 1

            private let _internalState = Atomic<_InternalState>(_InternalState(count: 1))

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
          @ThreadSafeProperty
          var count: Int
          @ThreadSafeInitializer([
              "count": TypeInfo<Int>(),
          ])

          init(count: Int) {
            self.count = count
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
      ])
  }

  func testInitializerWithDefaultValues() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
        var count: Int = 1
        var name: String?

        init(count: Int, name: String?) {
          self.count = count
          self.name = name
        }
      }
      """,
      expandedSource: """
        final class Example {
          @ThreadSafeProperty
          var count: Int = 1
          @ThreadSafeProperty
          var name: String?
          @ThreadSafeInitializer([
              "count": TypeInfo<Int>(defaultValue: 1),
              "name": TypeInfo<String?>(defaultValue: nil),
          ])

          init(count: Int, name: String?) {
            self.count = count
            self.name = name
          }

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
              var count: Int
              var name: String?
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
      ])
  }

  func testInitializerWithDefaultValuesAndImplicitType() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      final class Example {
        var count = [Int]()

        init(count: [Int]) {
          self.count = count
        }
      }
      """,
      expandedSource: """
        final class Example {
          @ThreadSafeProperty
          var count = [Int]()
          @ThreadSafeInitializer([
              "count": TypeInfo<[Int]>(defaultValue: [Int]()),
          ])

          init(count: [Int]) {
            self.count = count
          }

            private let _internalState: Atomic<_InternalState>

            private struct _InternalState: Sendable {
              var count: [Int]
            }

            @discardableResult
              private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
                _internalState.mutate(mutation)
              }
        }
        """,
      macros: [
        "ThreadSafe": ThreadSafeMacro.self,
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
          @ThreadSafeProperty
          var count: Int
          let foo: String

          convenience init(count: Int) {
            self.init(count: count, foo: "foo")
          }
          @ThreadSafeInitializer([
              "count": TypeInfo<Int>(),
          ])

          init(count: Int, foo: String) {
            self.count = count
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
      ])
  }

  func testThreadSafeMacroOnlyExpandsCorrectVar() {
    // Test that the Sendable macro adds the correct attributes and members
    assertMacroExpansion(
      """
      @ThreadSafe
      public final class Example {
        var count: Int = 1
        let value: String
        var name: String { "name" }
        @Dependency var foo
      }
      """,
      expandedSource: """
        public final class Example {
          @ThreadSafeProperty
          var count: Int = 1
          let value: String
          var name: String { "name" }
          @Dependency var foo

            private let _internalState = Atomic<_InternalState>(_InternalState(count: 1))

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
      ])
  }

  func testThreadSafeMacroInfersTypeCorrectly() {
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
          @ThreadSafeProperty
          var count = 0
          @ThreadSafeProperty
          var isActive = false
          @ThreadSafeInitializer([
              "count": TypeInfo<Int>(defaultValue: 0),
              "isActive": TypeInfo<Bool>(defaultValue: false),
          ])
          init() {}

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
      ])
  }
}
