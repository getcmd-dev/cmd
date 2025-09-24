// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftTesting
import Testing
@testable import ChatFeature

struct StringExtensionTests {

  @Test("String withTrailingNewline adds newline when missing")
  func test_withTrailingNewline_addsNewlineWhenMissing() {
    // given
    let text = "Hello, World!"

    // when
    let result = text.withTrailingNewline

    // then
    #expect(result == "Hello, World!\n")
  }

  @Test("String withTrailingNewline preserves existing newline")
  func test_withTrailingNewline_preservesExistingNewline() {
    // given
    let text = "Hello, World!\n"

    // when
    let result = text.withTrailingNewline

    // then
    #expect(result == "Hello, World!\n")
  }

  @Test("String withTrailingNewline handles empty string")
  func test_withTrailingNewline_handlesEmptyString() {
    // given
    let text = ""

    // when
    let result = text.withTrailingNewline

    // then
    #expect(result == "\n")
  }

  @Test("String withTrailingNewline handles string with only newline")
  func test_withTrailingNewline_handlesStringWithOnlyNewline() {
    // given
    let text = "\n"

    // when
    let result = text.withTrailingNewline

    // then
    #expect(result == "\n")
  }

  @Test("String withTrailingNewline handles multiple newlines")
  func test_withTrailingNewline_handlesMultipleNewlines() {
    // given
    let text = "Hello\n\n"

    // when
    let result = text.withTrailingNewline

    // then
    #expect(result == "Hello\n\n")
  }
}
