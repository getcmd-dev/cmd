// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import JSONFoundation
import LocalServerServiceInterface
import SwiftTesting
import Testing
@testable import LocalServerService

// MARK: - DataExtensionTests

enum DataExtensionTests {
  struct JSONObjects {

    @Test("Single JSON value")
    func decodeSingleJSONValue() throws {
      try validateObjectDecoding(
        "{\"key\": \"value\"}",
        [["key": .string("value")]])
    }

    @Test("Single JSON value with nested object")
    func decodeNestedJSONValue() throws {
      try validateObjectDecoding(
        "{\"key\": \"value\", \"nested\": {\"key\": \"value\"}}",
        [[
          "key": .string("value"),
          "nested": ["key": .string("value")],
        ]])
    }

    @Test("Several JSON value")
    func decodeSeveralJSONValue() throws {
      try validateObjectDecoding(
        "{\"key\": \"value\"}{\"key\": \"value\", \"nested\": {\"key\": \"value\"}}",
        [
          ["key": .string("value")],
          [
            "key": .string("value"),
            "nested": ["key": .string("value")],
          ],
        ])
    }

    @Test("Several JSON value with spacing")
    func decodeSeveralJSONValueWithSpacing() throws {
      try validateObjectDecoding(
        """
        {"key": "value"}
            {"key": "value", "nested": {"key": "value"}}
        """,
        [
          ["key": .string("value")],
          [
            "key": .string("value"),
            "nested": ["key": .string("value")],
          ],
        ])
    }

    @Test("Several JSON value with spacing and escaped characters")
    func decodeSeveralJSONValueWithSpacingAndEscapedCharacters() throws {
      try validateObjectDecoding(
        """
        {"key": "val{u}e"}
            {"key": "value", "nested": {"key": "val\\"{u}e"}}
        """,
        [
          ["key": .string("val{u}e")],
          [
            "key": .string("value"),
            "nested": ["key": .string("val\"{u}e")],
          ],
        ])
    }
  }

  struct JSONObjectsWithTruncatedData {

    @Test("Partial JSON value")
    func decodePartialJSONValue() throws {
      try validateObjectDecoding(
        "{\"key\": \"val",
        [],
        truncatedData: "{\"key\": \"val")
    }

    @Test("Single JSON value")
    func decodeSingleJSONValue() throws {
      try validateObjectDecoding(
        "{\"key\": \"value\"}  {\"key\": \"valu",
        [["key": .string("value")]],
        truncatedData: "{\"key\": \"valu")
    }

    @Test("Several JSON value with spacing")
    func decodeSeveralJSONValueWithSpacing() throws {
      try validateObjectDecoding(
        """
        {"key": "value"}
            {"key": "value", "nested": {"key": "value"}}
                {\"key\": \"valu
        """,
        [
          ["key": .string("value")],
          [
            "key": .string("value"),
            "nested": ["key": .string("value")],
          ],
        ],
        truncatedData: "{\"key\": \"valu")
    }

    @Test("Several JSON value with spacing and escaped characters")
    func decodeSeveralJSONValueWithSpacingAndEscapedCharacters() throws {
      try validateObjectDecoding(
        """
        {"key": "val{u}e"}
            {"key": "value", "nested": {"key": "val\\"{u}e"}}
                    {"key": "value", "nested": {"key": "val\\"{u
        """,
        [
          ["key": .string("val{u}e")],
          [
            "key": .string("value"),
            "nested": ["key": .string("val\"{u}e")],
          ],
        ],
        truncatedData: """
              {"key": "value", "nested": {"key": "val\\"{u
          """)
    }
  }
}

/// Validate that extracting JSON objects from `jsonsRepresentation` yields the expected values,
/// and that the truncated data also match the expectation.
private func validateObjectDecoding(
  _ jsonsRepresentation: String,
  _ expectedJSONObjects: [JSON],
  truncatedData expectedTruncatedData: String = "")
  throws
{
  let data = jsonsRepresentation.utf8Data
  let (objects, truncatedData) = data.parseJSONObjects()
  let jsons = objects.map { object in
    object.jsonString()
  }

  let expectedJSONs = try expectedJSONObjects.map { jsonObject in
    try jsonObject.asJSONData().jsonString()
  }
  #expect(jsons.count == expectedJSONs.count)
  for (json, expectedJSON) in zip(jsons, expectedJSONs) {
    #expect(json == expectedJSON)
  }

  let truncatedDataStr = (truncatedData.map { String(data: $0, encoding: .utf8) } ?? nil) ?? ""
  #expect(
    expectedTruncatedData.trimmingCharacters(in: .whitespacesAndNewlines) ==
      truncatedDataStr.trimmingCharacters(in: .whitespacesAndNewlines))
}

// MARK: - DataStreamTests

struct DataStreamTests {
  @Test
  func receivesValidJSON() async throws {
    let firstObjectReceived = expectation(description: "first object received")
    let secondObjectReceived = expectation(description: "second object received")

    let (rawDataStream, continuation) = AsyncStream<Data>.makeStream()
    let jsonStream = rawDataStream.jsonStream

    func send(_ data: String) {
      let data = data.utf8Data
      continuation.yield(data)
    }

    var receivedObjects = [Data]()
    Task {
      for try await object in jsonStream {
        receivedObjects.append(object)
        if receivedObjects.count == 1 {
          firstObjectReceived.fulfill()
        } else if receivedObjects.count == 2 {
          secondObjectReceived.fulfill()
        }
      }
    }

    send(#"{"key": "va"#)
    send(#"lue"}{"key": "value", "nes"#)
    try await fulfillment(of: firstObjectReceived)
    send(#"ted": {"key": "value"}}"#)
    try await fulfillment(of: secondObjectReceived)
  }
}
