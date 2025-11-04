// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import JRPCService

@Suite("JSON Streaming Parser Tests")
struct JSONStreamingParserTests {

  // MARK: - Single Complete Objects

  @Test("Parses a single complete JSON object")
  func parsesSingleCompleteObject() {
    // given
    let json = #"{"id":1,"method":"test"}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  @Test("Parses a single complete nested object")
  func parsesSingleCompleteNestedObject() {
    // given
    let json = #"{"id":1,"params":{"nested":{"deeply":"value"}}}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  // MARK: - Multiple Complete Objects

  @Test("Parses multiple complete JSON objects concatenated")
  func parsesMultipleCompleteObjects() {
    // given
    let json1 = #"{"id":1,"method":"test1"}"#
    let json2 = #"{"id":2,"method":"test2"}"#
    let json3 = #"{"id":3,"method":"test3"}"#
    let combined = json1 + json2 + json3
    let data = Data(combined.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 3)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json1)
    #expect(String(data: result.objects[1], encoding: .utf8) == json2)
    #expect(String(data: result.objects[2], encoding: .utf8) == json3)
  }

  // MARK: - Truncated Objects

  @Test("Handles truncated JSON object at the end")
  func handlesTruncatedObject() {
    // given
    let complete = #"{"id":1,"method":"test"}"#
    let truncated = #"{"id":2,"met"#
    let combined = complete + truncated
    let data = Data(combined.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(String(data: result.objects[0], encoding: .utf8) == complete)
    #expect(result.truncatedData != nil)
    #expect(String(data: result.truncatedData!, encoding: .utf8) == truncated)
  }

  @Test("Handles only truncated JSON object")
  func handlesOnlyTruncatedObject() {
    // given
    let truncated = #"{"id":1,"met"#
    let data = Data(truncated.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.isEmpty)
    #expect(result.truncatedData != nil)
    #expect(String(data: result.truncatedData!, encoding: .utf8) == truncated)
  }

  // MARK: - Strings with Special Characters

  @Test("Handles JSON objects with string values containing braces")
  func handlesStringsWithBraces() {
    // given
    let json = #"{"id":1,"content":"This {has} braces {}"}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  @Test("Handles JSON objects with escaped quotes")
  func handlesEscapedQuotes() {
    // given
    let json = #"{"id":1,"message":"He said \"hello\""}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  @Test("Handles JSON objects with escaped backslashes")
  func handlesEscapedBackslashes() {
    // given
    let json = #"{"path":"C:\\Users\\test\\file.txt"}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  @Test("Handles complex string with multiple escape sequences")
  func handlesComplexEscapeSequences() {
    // given
    let json = #"{"msg":"Line1\nLine2\tTab\"Quote\"\\Backslash"}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  // MARK: - Edge Cases

  @Test("Handles empty data")
  func handlesEmptyData() {
    // given
    let data = Data()

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.isEmpty)
    // When empty, currentChunkStartIndex is 0, so returns empty Data
    #expect(result.truncatedData != nil)
    #expect(result.truncatedData?.isEmpty == true)
  }

  @Test("Handles only opening brace")
  func handlesOnlyOpeningBrace() {
    // given
    let data = Data("{".utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.isEmpty)
    #expect(result.truncatedData != nil)
    #expect(String(data: result.truncatedData!, encoding: .utf8) == "{")
  }

  @Test("Handles nested objects with multiple levels")
  func handlesDeepNesting() {
    // given
    let json = #"{"a":{"b":{"c":{"d":{"e":"value"}}}}}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  @Test("Handles whitespace between objects")
  func handlesWhitespaceBetweenObjects() {
    // given
    let json1 = #"{"id":1}"#
    let json2 = #"{"id":2}"#
    let combined = json1 + "   \n  " + json2
    let data = Data(combined.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 2)
    #expect(String(data: result.objects[0], encoding: .utf8) == json1)
    #expect(String(data: result.objects[1], encoding: .utf8) == json2)
  }

  @Test("Handles multiple complete objects with one truncated")
  func handlesMultipleWithOneTruncated() {
    // given
    let json1 = #"{"id":1}"#
    let json2 = #"{"id":2}"#
    let truncated = #"{"id":3,"par"#
    let combined = json1 + json2 + truncated
    let data = Data(combined.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 2)
    #expect(String(data: result.objects[0], encoding: .utf8) == json1)
    #expect(String(data: result.objects[1], encoding: .utf8) == json2)
    #expect(result.truncatedData != nil)
    #expect(String(data: result.truncatedData!, encoding: .utf8) == truncated)
  }

  // MARK: - Real-World LSP Scenarios

  @Test("Handles typical LSP notification")
  func handlesTypicalLSPNotification() {
    // given
    let json = #"{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"file:///test.swift","diagnostics":[]}}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  @Test("Handles LSP response with result")
  func handlesLSPResponse() {
    // given
    let json = #"{"jsonrpc":"2.0","id":1,"result":{"capabilities":{"textDocumentSync":1}}}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }

  @Test("Handles strings with JSON-like content")
  func handlesStringsWithJSONLikeContent() {
    // given
    let json = #"{"code":"function test() { return {\"key\": \"value\"}; }"}"#
    let data = Data(json.utf8)

    // when
    let result = data.parseJSONObjects()

    // then
    #expect(result.objects.count == 1)
    #expect(result.truncatedData == nil)
    #expect(String(data: result.objects[0], encoding: .utf8) == json)
  }
}
