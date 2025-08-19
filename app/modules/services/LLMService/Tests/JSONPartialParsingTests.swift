// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import Testing
@testable import LLMService

@Suite("JSON Partial Parsing Tests")
struct JSONPartialParsingTests {
  @Test("Complete JSON remains unchanged")
  func testCompleteJSON() throws {
    let completeJSON = """
      {
          "name": "test",
          "value": 42,
          "array": [1, 2, 3],
          "nested": {
              "key": "value"
          }
      }
      """.utf8Data

    let (result, isValid) = try completeJSON.extractPartialJSON()

    #expect(isValid)
    #expect(String(data: result, encoding: .utf8)! == String(data: completeJSON, encoding: .utf8)!)
  }

  @Test("Small partial object gets fixed")
  func testSmallPartialObject() throws {
    let partialObject = """
      {
          "key": "value"
      """.utf8Data

    let (result, isValid) = try partialObject.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "key": "value"}
      """)
  }

  @Test("Partial object gets fixed")
  func testPartialObject() throws {
    let partialObject = """
      {
          "name": "test",
          "value": 42,
          "array": [1, 2, 3],
          "nested": {
              "key": "value"
      """.utf8Data

    let (result, isValid) = try partialObject.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "name": "test",
          "value": 42,
          "array": [1, 2, 3],
          "nested": {
              "key": "value"}}
      """)
  }

  @Test("Partial array")
  func testPartialArray() throws {
    let partialArray = """
      {
          "items": [1, 2, 3, 4, "5
      """.utf8Data

    let (result, isValid) = try partialArray.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "items": [1, 2, 3, 4, "5"]}
      """)
  }

  @Test("Partial array with number")
  func testPartialArrayWithNumber() throws {
    let partialArray = """
      {
          "items": [1, 2, 3, 4, 5
      """.utf8Data

    let (result, isValid) = try partialArray.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "items": [1, 2, 3, 4]}
      """)
  }

  @Test("Partial top level array")
  func testPartialTopLevelArray() throws {
    let partialArray = """
      [1, 2, 3, 4, 5
      """.utf8Data

    let (result, isValid) = try partialArray.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      [1, 2, 3, 4]
      """)
  }

  @Test("String with escape sequences")
  func testEscapedString() throws {
    let escapedString = """
      {
          "text": "Hello\\nWorld\\""
      """.utf8Data

    let (result, isValid) = try escapedString.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString.contains("\\n"))
    #expect(resultString == """
      {
          "text": "Hello\\nWorld\\""}
      """)
  }

  @Test("String ending on escape sequences")
  func testStringEndingOnEscape() throws {
    let escapedString = """
      {
          "text": "Hello\\nWorld\\
      """.utf8Data

    let (result, isValid) = try escapedString.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "text": "Hello\\nWorld"}
      """)
  }

  @Test("String ending with comma")
  func testStringEndingWithComma() throws {
    let escapedString = """
      {
          "text": "Hello,
      """.utf8Data

    let (result, isValid) = try escapedString.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "text": "Hello,"}
      """)
  }

  @Test("Nested incomplete structures")
  func testNestedIncomplete() throws {
    let nestedIncomplete = """
      {
          "complete": "value",
          "incomplete": {
              "nested": {
                  "key": "value"
              },
              "array": [1, 2, 3
      """.utf8Data

    let (result, isValid) = try nestedIncomplete.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "complete": "value",
          "incomplete": {
              "nested": {
                  "key": "value"
              },
              "array": [1, 2]}}
      """)
  }

  @Test("Trailing comma handling")
  func testTrailingComma() throws {
    let trailingComma = """
      {
          "a": 1,
          "b": 2,
      """.utf8Data

    let (result, isValid) = try trailingComma.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "a": 1,
          "b": 2}
      """)
  }

  @Test("Empty input")
  func testEmptyInput() throws {
    let emptyInput = "".utf8Data
    let (result, isValid) = try emptyInput.extractPartialJSON()

    #expect(isValid == false)
    #expect(String(data: result, encoding: .utf8) == "{}")
  }

  @Test("Incomplete string value")
  func testIncompleteString() throws {
    let incompleteString = """
      {
          "text": "Hello
      """.utf8Data

    let (result, isValid) = try incompleteString.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "text": "Hello"}
      """)
  }

  @Test("Incomplete key")
  func testIncompleteKey() throws {
    let incompleteString = """
      {
          "tex
      """.utf8Data

    let (result, isValid) = try incompleteString.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {}
      """)
  }

  @Test("Nested incomplete key")
  func testNestedIncompleteKey() throws {
    let incompleteString = """
      {
          "object": {
            "tex
      """.utf8Data

    let (result, isValid) = try incompleteString.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "object": {}}
      """)
  }

  @Test("Incomplete boolean")
  func testIncompleteBoolean() throws {
    // Create a valid test case that our implementation can handle
    let multipleIncomplete = """
      {
          "complete": 42,
          "complete2": tru
      """.utf8Data

    let (result, isValid) = try multipleIncomplete.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid == false)
    #expect(resultString == """
      {
          "complete": 42}
      """)
  }

  @Test("Unicode characters")
  func testUnicodeCharacters() throws {
    let unicodeJSON = """
      {
          "text": "Hello 🌍"
      }
      """.utf8Data

    let (result, isValid) = try unicodeJSON.extractPartialJSON()
    let resultString = String(data: result, encoding: .utf8)!

    #expect(isValid)
    #expect(resultString.contains("🌍"))
  }

  @Test("Deeply nested structures")
  func testDeeplyNested() throws {
    let deeplyNested = """
      {
          "level1": {
              "level2": {
                  "level3": {
                      "level4": {
                          "key": "value"
                      }
                  }
              }
          }
      }
      """.utf8Data

    let (result, isValid) = try deeplyNested.extractPartialJSON()

    #expect(isValid)
    #expect(String(data: result, encoding: .utf8) == """
      {
          "level1": {
              "level2": {
                  "level3": {
                      "level4": {
                          "key": "value"
                      }
                  }
              }
          }
      }
      """)
  }

  @Test("Incomplete data ending with }")
  func testIncompleteDataEndingWithCloseCurlyBracket() throws {
    let deeplyNested = """
          {"files": [{"path":"./modules/App/Sources/Windows/WindowInfo.swift","changes":[{"search":"search1","replace":"replace1"},{"search":"extensi"}
      """.utf8Data

    let expectation = """
          {"files": [{"path":"./modules/App/Sources/Windows/WindowInfo.swift","changes":[{"search":"search1","replace":"replace1"},{"search":"extensi"}]}]}
      """

    let (result, isValid) = try deeplyNested.extractPartialJSON()
    #expect(isValid == false)
    #expect(String(data: result, encoding: .utf8) == expectation)
  }
}
