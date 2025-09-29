// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import MCPService

// MARK: - StringSanitizedTests

@Suite("StringSanitizedTests")
struct StringSanitizedTests {

  @Test("converts camelCase to snake_case")
  func testCamelCaseToSnakeCase() {
    #expect("camelCase".sanitized == "camel_case")
    #expect("CamelCase".sanitized == "camel_case")
    #expect("XMLParser".sanitized == "xml_parser")
    #expect("iPhone".sanitized == "i_phone")
  }

  @Test("handles spaces")
  func testSpaces() {
    #expect("hello world".sanitized == "hello_world")
    #expect("multi word string".sanitized == "multi_word_string")
    #expect("  spaces  ".sanitized == "spaces")
  }

  @Test("handles special characters")
  func testSpecialCharacters() {
    #expect("hello@world".sanitized == "hello_world")
    #expect("test-function".sanitized == "test_function")
    #expect("name.extension".sanitized == "name_extension")
    #expect("mixed!@#$%characters".sanitized == "mixed_characters")
  }

  @Test("preserves underscores")
  func testUnderscores() {
    #expect("already_snake_case".sanitized == "already_snake_case")
    #expect("mixed_camelCase".sanitized == "mixed_camel_case")
    #expect("__double__underscores__".sanitized == "double_underscores")
  }

  @Test("handles edge cases")
  func testEdgeCases() {
    #expect("".sanitized == "")
    #expect("a".sanitized == "a")
    #expect("A".sanitized == "a")
    #expect("123".sanitized == "123")
    #expect("test123".sanitized == "test123")
    #expect("test123ABC".sanitized == "test123_abc")
  }

  @Test("handles consecutive uppercase letters")
  func testConsecutiveUppercase() {
    #expect("XMLHttpRequest".sanitized == "xml_http_request")
    #expect("HTTPSConnection".sanitized == "https_connection")
    #expect("UIViewController".sanitized == "ui_view_controller")
  }

}
