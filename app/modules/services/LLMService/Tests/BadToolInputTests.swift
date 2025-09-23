// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import LLMService

// MARK: - BadToolInputTests

@Suite("Bad Tool Input Handling Tests")
struct BadToolInputTests {

  @Test("DecodingError provides detailed LLM error description")
  func testDecodingErrorLLMDescription() throws {
    // Test keyNotFound error
    let keyNotFoundContext = DecodingError.Context(
      codingPath: [MockCodingKey(stringValue: "files"), MockCodingKey(intValue: 0), MockCodingKey(stringValue: "path")],
      debugDescription: "No value associated with key 'path'")
    let keyNotFoundError = DecodingError.keyNotFound(MockCodingKey(stringValue: "path"), keyNotFoundContext)

    let errorDescription = keyNotFoundError.llmErrorDescription
    #expect(errorDescription.contains("files[0].path"))
    #expect(errorDescription.contains("No value associated with key 'path'"))

    // Test typeMismatch error
    let typeMismatchContext = DecodingError.Context(
      codingPath: [MockCodingKey(stringValue: "files"), MockCodingKey(intValue: 0), MockCodingKey(stringValue: "changes")],
      debugDescription: "Expected to decode Array but found a string")
    let typeMismatchError = DecodingError.typeMismatch([String].self, typeMismatchContext)

    let typeMismatchDescription = typeMismatchError.llmErrorDescription
    #expect(typeMismatchDescription.contains("files[0].changes"))
    #expect(typeMismatchDescription.contains("Expected to decode Array but found a string"))
  }

  @Test("DecodingError context coding path description is formatted correctly")
  func testCodingPathDescription() throws {
    let codingPath: [any CodingKey] = [
      MockCodingKey(stringValue: "root"),
      MockCodingKey(intValue: 2),
      MockCodingKey(stringValue: "nested"),
      MockCodingKey(stringValue: "value"),
    ]

    let description = codingPath.description
    #expect(description == ".root[2].nested.value")
  }

  @Test("Empty coding path returns empty description")
  func testEmptyCodingPath() throws {
    let emptyCodingPath = [any CodingKey]()
    let description = emptyCodingPath.description
    #expect(description == "")
  }

  @Test("Array-only coding path is formatted correctly")
  func testArrayOnlyCodingPath() throws {
    let arrayOnlyCodingPath: [any CodingKey] = [
      MockCodingKey(intValue: 0),
      MockCodingKey(intValue: 1),
      MockCodingKey(intValue: 2),
    ]

    let description = arrayOnlyCodingPath.description
    #expect(description == "[0][1][2]")
  }

  @Test("Mixed coding path with root array is formatted correctly")
  func testMixedCodingPathWithRootArray() throws {
    let mixedCodingPath: [any CodingKey] = [
      MockCodingKey(intValue: 0),
      MockCodingKey(stringValue: "property"),
      MockCodingKey(intValue: 5),
      MockCodingKey(stringValue: "value"),
    ]

    let description = mixedCodingPath.description
    #expect(description == "[0].property[5].value")
  }

  @Test("ValueNotFound error provides context description")
  func testValueNotFoundError() throws {
    let context = DecodingError.Context(
      codingPath: [MockCodingKey(stringValue: "required_field")],
      debugDescription: "Expected String value but found null")
    let error = DecodingError.valueNotFound(String.self, context)

    let description = error.llmErrorDescription
    #expect(description.contains("required_field"))
    #expect(description.contains("Expected String value but found null"))
  }

  @Test("DataCorrupted error provides context description")
  func testDataCorruptedError() throws {
    let context = DecodingError.Context(
      codingPath: [MockCodingKey(stringValue: "malformed_json")],
      debugDescription: "The given data was not valid JSON")
    let error = DecodingError.dataCorrupted(context)

    let description = error.llmErrorDescription
    #expect(description.contains("malformed_json"))
    #expect(description.contains("The given data was not valid JSON"))
  }

  @Test("DecodingError with underlying error provides comprehensive description")
  func testDecodingErrorWithUnderlyingError() throws {
    let underlyingError = NSError(
      domain: "TestDomain",
      code: 123,
      userInfo: [NSDebugDescriptionErrorKey: "Underlying error details"])

    let context = DecodingError.Context(
      codingPath: [MockCodingKey(stringValue: "test")],
      debugDescription: "Main error description",
      underlyingError: underlyingError)

    let error = DecodingError.dataCorrupted(context)
    let description = error.llmErrorDescription
    #expect(description.contains("Main error description"))
    #expect(description.contains("Underlying error details"))
    #expect(description.contains("test"))
  }
}

// MARK: - MockCodingKey

private struct MockCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init(intValue: Int) {
    stringValue = "\(intValue)"
    self.intValue = intValue
  }
}
