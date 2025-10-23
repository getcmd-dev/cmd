// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import JSONFoundation
import SwiftTesting
import Testing
@testable import ToolFoundation

// MARK: - UnknownToolTests

struct UnknownToolTests {
  @Test
  func test_originalToolCanBeDecodedAsUnknownTool() async throws {
    // Given - Create a tool use with an MCP tool
    let tool = TestTool(output: .success(.object(["foo": "bar"])))
    let originalToolUse = TestTool.Use(
      callingTool: tool,
      toolUseId: "tool-use-id",
      input: [:],
      context: toolExecutionContext,
      internalState: nil,
      initialStatus: .notStarted as ToolUseExecutionStatus<JSON.Value>)
    originalToolUse.startExecuting()

    // Wait for the status to be updated asynchronously
    for await status in originalToolUse.status.futureUpdates {
      if case .completed = status { break }
    }

    // Encode the original tool use
    let data = try JSONEncoder().encode(WrappedToolUse(toolUse: originalToolUse))

    // Create decoder without the original tool available (simulating tool no longer exists)
    let toolsPlugin = ToolsPlugin()
    let decoder = JSONDecoder()
    decoder.userInfo.set(toolPlugin: toolsPlugin)

    // When - Decode as UnknownToolTestTool
    let decodedToolUse = try decoder.decode(WrappedToolUse.self, from: data).toolUse

    // Then - Verify the UnknownTool preserves all original data
    #expect(decodedToolUse.toolName == originalToolUse.toolName)
    #expect(decodedToolUse.toolUseId == originalToolUse.toolUseId)
    let unknownToolUse = try #require(decodedToolUse as? ToolFoundation.UnknownTool.Use)
    #expect(try unknownToolUse.status.value.asOutput == ["foo": "bar"])
    #expect(decodedToolUse.callingTool is UnknownTool)
  }

  @Test
  func test_unknownToolEncodingPreservesOriginalData() throws {
    // Given - Create original tool use and decode it as UnknownTool
    let tool = TestTool(output: .success(.object(["foo": .string("bar")])))
    let originalToolUse = TestTool.Use(
      callingTool: tool,
      toolUseId: "tool-use-id",
      input: ["foo": "bar"],
      context: toolExecutionContext,
      internalState: nil,
      initialStatus: .notStarted as ToolUseExecutionStatus<JSON.Value>)

    let originalData = try JSONEncoder().encode(WrappedToolUse(toolUse: originalToolUse))

    // Decode as UnknownTool
    let toolsPlugin = ToolsPlugin()
    let decoder = JSONDecoder()
    decoder.userInfo.set(toolPlugin: toolsPlugin)
    let unknownToolUse = try decoder.decode(WrappedToolUse.self, from: originalData).toolUse
    #expect(unknownToolUse as? UnknownTool.Use != nil)

    // When - Re-encode the UnknownTool
    let reEncodedData = try JSONEncoder().encode(WrappedToolUse(toolUse: unknownToolUse))

    // Then - Verify no data loss by decoding back to original type
    let finalToolsPlugin = ToolsPlugin()
    finalToolsPlugin.plugIn(tool: tool)
    let finalDecoder = JSONDecoder()
    finalDecoder.userInfo.set(toolPlugin: finalToolsPlugin)
    let finalToolUse = try #require(try finalDecoder.decode(WrappedToolUse.self, from: originalData).toolUse as? TestTool.Use)

    reEncodedData.expectToMatch("""
      {
        "callingTool" : "TestTool",
        "toolUse" : {
          "callingTool" : "TestTool",
          "context" : {
            "threadId" : "mock-thread-id"
          },
          "input" : {
            "foo" : "bar"
          },
          "internalState" : {
            "isExternalAgent" : false
          },
          "status" : {
            "status" : "notStarted"
          },
          "toolUseId" : "tool-use-id"
        }
      }
      """)
    #expect(finalToolUse.toolName == originalToolUse.toolName)
    #expect(finalToolUse.toolUseId == originalToolUse.toolUseId)
    #expect(try finalToolUse.output.get() == .object(["foo": .string("bar")]))
    #expect(type(of: finalToolUse.callingTool) == type(of: originalToolUse.callingTool))
  }

  private let toolExecutionContext = ToolExecutionContext()
}

// MARK: - WrappedToolUse

/// A keyed object that contains a tool use.
/// Encode / decodes similarly to how `ChatMessageToolUseContentModel` does it.
private struct WrappedToolUse: Codable {
  init(toolUse: any ToolUse) {
    self.toolUse = toolUse
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let tool = try container.decodeAnyTool(forKey: .callingTool)
    try self.init(
      toolUse: container.decode(useOf: tool, forKey: .toolUse))
  }

  enum CodingKeys: String, CodingKey {
    case id, toolUse, callingTool
  }

  let toolUse: any ToolUse

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(toolUse.callingTool, forKey: .callingTool)
    try container.encode(toolUse, forKey: .toolUse)
  }

}
