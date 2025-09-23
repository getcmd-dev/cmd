// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftTesting
import Testing
@testable import ReadFileTool

struct ArraySafeSubscriptTests {

  @Test("safe subscript handles normal ranges")
  func test_normalRanges() {
    let array = ["Line 1", "Line 2", "Line 3", "Line 4", "Line 5"]

    let result1 = array.safeRange(from: 1, to: 4)
    #expect(result1 == ["Line 2", "Line 3", "Line 4"])

    let result2 = array.safeRange(from: 0, to: 3)
    #expect(result2 == ["Line 1", "Line 2", "Line 3"])

    let result3 = array.safeRange(from: 2, to: 5)
    #expect(result3 == ["Line 3", "Line 4", "Line 5"])
  }

  @Test("safe subscript handles out of bounds ranges")
  func test_outOfBoundsRanges() {
    let array = ["Line 1", "Line 2", "Line 3"]

    // Range extending beyond array bounds
    let result1 = array.safeRange(from: 1, to: 10)
    #expect(result1 == ["Line 2", "Line 3"])

    // Start beyond bounds
    let result2 = array.safeRange(from: 5, to: 8)
    #expect(result2 == nil)

    // Both bounds beyond array
    let result3 = array.safeRange(from: 10, to: 15)
    #expect(result3 == nil)
  }

  @Test("safe subscript handles negative start values")
  func test_negativeStartValues() {
    let array = ["Line 1", "Line 2", "Line 3"]

    // Negative start should be clamped to 0
    let result1 = array.safeRange(from: -2, to: 2)
    #expect(result1 == ["Line 1", "Line 2"])

    let result2 = array.safeRange(from: -5, to: 1)
    #expect(result2 == ["Line 1"])

    let result3 = array.safeRange(from: -1, to: 3)
    #expect(result3 == ["Line 1", "Line 2", "Line 3"])
  }

  @Test("safe subscript handles negative end bounds")
  func test_negativeEndBounds() {
    let array = ["Line 1", "Line 2", "Line 3", "Line 4", "Line 5"]

    let result1 = array.safeRange(from: 0, to: -1)
    #expect(result1 == ["Line 1", "Line 2", "Line 3", "Line 4", "Line 5"])

    let result2 = array.safeRange(from: 0, to: -2)
    #expect(result2 == ["Line 1", "Line 2", "Line 3", "Line 4"])

    let result3 = array.safeRange(from: 2, to: -1)
    #expect(result3 == ["Line 3", "Line 4", "Line 5"])
  }

  @Test("safe subscript handles empty ranges")
  func test_emptyRanges() {
    let array = ["Line 1", "Line 2", "Line 3"]

    // Start equals end (after adjustment)
    let result1 = array.safeRange(from: 2, to: 2)
    #expect(result1 == nil)

    // Start greater than end
    let result2 = array.safeRange(from: 3, to: 2)
    #expect(result2 == nil)

    // Zero-length range at start
    let result3 = array.safeRange(from: 0, to: 0)
    #expect(result3 == nil)
  }

  @Test("safe subscript handles edge cases")
  func test_edgeCases() {
    let array = ["A", "B", "C"]

    // Single element ranges
    let result1 = array.safeRange(from: 0, to: 1)
    #expect(result1 == ["A"])

    let result2 = array.safeRange(from: 2, to: 3)
    #expect(result2 == ["C"])

    // Full array
    let result3 = array.safeRange(from: 0, to: 3)
    #expect(result3 == ["A", "B", "C"])

    // Beyond full array
    let result4 = array.safeRange(from: 0, to: 10)
    #expect(result4 == ["A", "B", "C"])
  }

  @Test("safe subscript with empty array")
  func test_emptyArray() {
    let array = [String]()

    let result1 = array.safeRange(from: 0, to: 1)
    #expect(result1 == nil)

    let result2 = array.safeRange(from: -1, to: 1)
    #expect(result2 == nil)

    let result3 = array.safeRange(from: 0, to: 0)
    #expect(result3 == nil)
  }
}
