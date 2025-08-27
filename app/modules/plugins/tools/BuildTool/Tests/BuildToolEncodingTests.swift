// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftTesting
import Testing
import ToolFoundation
import XcodeControllerServiceInterface
@testable import BuildTool

// MARK: - BuildToolEncodingTests

struct BuildToolEncodingTests {

  // MARK: - Tool Use Encoding/Decoding Tests

  @Test("Tool Use encoding/decoding - test build")
  func test_toolUseEncodingDecodingTest() throws {
    let tool = BuildTool()
    let input = BuildTool.Use.Input(for: .test)
    let use = tool.use(toolUseId: "build-test-789", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "build",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "for": "test"
        },
        "internalState": null,
        "isInputComplete": true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "build-test-789"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - run build")
  func test_toolUseEncodingDecodingRun() throws {
    let tool = BuildTool()
    let input = BuildTool.Use.Input(for: .run)
    let use = tool.use(toolUseId: "build-run-101", input: input, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool": "build",
        "context": {
          "threadId": "mock-thread-id"
        },
        "input": {
          "for": "run"
        },
        "internalState": null,
        "isInputComplete": true,
        "status": {
          "status": "notStarted"
        },
        "toolUseId": "build-run-101"
      }
      """)
  }
}

private let toolExecutionContext = ToolExecutionContext()

private func testDecodingEncodingWithTool(
  of value: some Codable,
  tool: any Tool,
  _ json: String)
  throws
{
  // Create decoder with tool plugin
  let toolsPlugin = ToolsPlugin()
  toolsPlugin.plugIn(tool: tool)
  let decoder = JSONDecoder()
  decoder.userInfo.set(toolPlugin: toolsPlugin)

  // Create encoder
  let encoder = JSONEncoder()

  // Use the test function with proper decoder/encoder
  try testDecodingEncoding(of: value, json, decoder: decoder, encoder: encoder)
}
