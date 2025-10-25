// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import JSONFoundation
import Testing
@testable import ToolFoundation

@Suite
struct ToolErrorTests {

  @Test("errorDescription returns string value for string JSON")
  func errorDescriptionWithString() {
    let error = ToolError(.string("Something went wrong"))

    #expect(error.errorDescription == "Something went wrong")
    #expect(error.localizedDescription == "Something went wrong")
  }

  @Test("errorDescription returns default message for empty array")
  func errorDescriptionWithEmptyArray() {
    let error = ToolError(.array([]))

    #expect(error.errorDescription == "The tool failed")
    #expect(error.localizedDescription == "The tool failed")
  }

  @Test("errorDescription joins array elements with comma")
  func errorDescriptionWithArray() {
    let error = ToolError(.array([
      .string("Error 1"),
      .string("Error 2"),
      .string("Error 3"),
    ]))

    #expect(error.errorDescription == "Error 1, Error 2, Error 3")
  }

  @Test("errorDescription handles nested arrays")
  func errorDescriptionWithNestedArray() {
    let error = ToolError(.array([
      .string("Top level"),
      .array([.string("Nested 1"), .string("Nested 2")]),
    ]))

    #expect(error.errorDescription == "Top level, Nested 1, Nested 2")
  }

  @Test("errorDescription converts number to string")
  func errorDescriptionWithNumber() {
    let error = ToolError(.number(42.5))

    #expect(error.errorDescription == "42.5")
  }

  @Test("errorDescription converts bool to string")
  func errorDescriptionWithBool() {
    let trueError = ToolError(.bool(true))
    let falseError = ToolError(.bool(false))

    #expect(trueError.errorDescription == "true")
    #expect(falseError.errorDescription == "false")
  }

  @Test("errorDescription returns 'null' for null value")
  func errorDescriptionWithNull() {
    let error = ToolError(.null)

    #expect(error.errorDescription == "null")
  }

  @Test("errorDescription formats object with key-value pairs")
  func errorDescriptionWithObject() {
    let error = ToolError(.object([
      "message": .string("Failed to connect"),
      "code": .number(500),
    ]))

    #expect(error.errorDescription == "code: 500.0\nmessage: Failed to connect")
  }

  @Test("errorDescription handles nested objects")
  func errorDescriptionWithNestedObject() {
    let error = ToolError(.object([
      "error": .object([
        "type": .string("NetworkError"),
        "details": .string("Connection timeout"),
      ]),
    ]))

    #expect(error.errorDescription == "error: details: Connection timeout\ntype: NetworkError")
  }

  @Test("errorUserInfo contains localized description")
  func errorUserInfoContainsDescription() {
    let error = ToolError(.string("Test error"))

    let userInfo = error.errorUserInfo
    let localizedDesc = userInfo[NSLocalizedDescriptionKey] as? String

    #expect(localizedDesc == "Test error")
  }

  @Test("errorDescription handles complex nested structures")
  func errorDescriptionWithComplexStructure() {
    let error = ToolError(.object([
      "errors": .array([
        .string("Error 1"),
        .object(["field": .string("username"), "message": .string("required")]),
      ]),
      "status": .number(400),
    ]))

    #expect(error.errorDescription == "errors: Error 1, field: username\nmessage: required\nstatus: 400.0")
  }
}
