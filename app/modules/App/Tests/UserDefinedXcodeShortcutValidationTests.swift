// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import SettingsServiceInterface
import SharedValuesFoundation
import SwiftTesting
import Testing
@testable import App

@MainActor
struct UserDefinedXcodeShortcutValidationTests {

  @Test("xcodeCommandIndex values must be unique")
  func test_xcodeCommandIndex_uniqueness() {
    // given
    let sut = [
      UserDefinedXcodeShortcut(name: "Test 1", command: "echo 1", xcodeCommandIndex: 0),
      UserDefinedXcodeShortcut(name: "Test 2", command: "echo 2", xcodeCommandIndex: 1),
      UserDefinedXcodeShortcut(name: "Test 3", command: "echo 3", xcodeCommandIndex: 0), // Duplicate!
    ]

    // when
    let indices = sut.map(\.xcodeCommandIndex)
    let uniqueIndices = Set(indices)

    // then
    #expect(indices.count != uniqueIndices.count, "Duplicate xcodeCommandIndex detected: \(indices)")
    #expect(indices.count == 3)
    #expect(uniqueIndices.count == 2)
  }

  @Test("xcodeCommandIndex values must be within bounds")
  func test_xcodeCommandIndex_bounds() {
    // given
    let validShortcuts = [
      UserDefinedXcodeShortcut(name: "Valid 1", command: "echo 1", xcodeCommandIndex: 0),
      UserDefinedXcodeShortcut(name: "Valid 2", command: "echo 2", xcodeCommandIndex: 9),
    ]

    // when/then
    for shortcut in validShortcuts {
      #expect(shortcut.xcodeCommandIndex >= 0, "xcodeCommandIndex must be >= 0")
      #expect(
        shortcut.xcodeCommandIndex < UserDefinedXcodeShortcutLimits.maxShortcuts,
        "xcodeCommandIndex must be < maxShortcuts")
    }
  }

  @Test("out of bounds indices are filtered correctly")
  func test_outOfBoundsIndices_filtering() {
    // given
    let sut = [
      UserDefinedXcodeShortcut(name: "Valid", command: "echo valid", xcodeCommandIndex: 0),
      UserDefinedXcodeShortcut(name: "Invalid High", command: "echo high", xcodeCommandIndex: 999),
      UserDefinedXcodeShortcut(name: "Invalid Low", command: "echo low", xcodeCommandIndex: -1),
    ]

    // when
    let validShortcuts = sut.filter { shortcut in
      shortcut.xcodeCommandIndex >= 0 &&
        shortcut.xcodeCommandIndex < UserDefinedXcodeShortcutLimits.maxShortcuts
    }

    // then
    #expect(validShortcuts.count == 1)
    #expect(validShortcuts[0].name == "Valid")
  }

  @Test("UserDefinedXcodeShortcutLimits has expected max value")
  func test_maxShortcuts_value() {
    // given/when
    let sut = UserDefinedXcodeShortcutLimits.maxShortcuts

    // then
    #expect(sut == 10, "maxShortcuts should be 10")
  }
}
