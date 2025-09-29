// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftTesting
import Testing
import ToolFoundation
@testable import ReadFileTool

// MARK: - ReadFileToolEncodingTests

extension ReadFileToolTests {

  struct EncodingTests {

    // MARK: - Tool Use Encoding/Decoding Tests

    @Test("Tool Use encoding/decoding - path only")
    func test_toolUseEncodingDecodingPathOnly() throws {
      let tool = ReadFileTool()
      let input = ReadFileTool.Use.Input(
        path: "/src/main.swift",
        lineRange: nil)
      let use = tool.use(toolUseId: "read-123", input: input, isInputComplete: true, context: toolExecutionContext)

      try testDecodingEncodingWithTool(of: use, tool: tool, """
        {
          "callingTool": "read_file",
          "context": {
            "threadId": "mock-thread-id"
          },
          "input": {
            "path": "/src/main.swift"
          },
          "internalState" : {
            "path" : "/src/main.swift"
          },
          "isInputComplete": true,
          "status": {
            "status": "notStarted"
          },
          "toolUseId": "read-123"
        }
        """)
    }

    @Test("Tool Use encoding/decoding - with line range")
    func test_toolUseEncodingDecodingWithRange() throws {
      let tool = ReadFileTool()
      let lineRange = ReadFileTool.Use.Input.Range(start: 5, end: 15)
      let input = ReadFileTool.Use.Input(
        path: "/test/file.py",
        lineRange: lineRange)
      let use = tool.use(toolUseId: "read-range-456", input: input, isInputComplete: true, context: toolExecutionContext)

      try testDecodingEncodingWithTool(of: use, tool: tool, """
        {
          "callingTool": "read_file",
          "context": {
            "threadId": "mock-thread-id"
          },
          "input": {
            "lineRange": {
              "end": 15,
              "start": 5
            },
            "path": "/test/file.py"
          },
          "internalState": {
            "lineRange" : {
              "end" : 15,
              "start" : 5
            },
            "path" : "/test/file.py"
          },
          "isInputComplete": true,
          "status": {
            "status": "notStarted"
          },
          "toolUseId": "read-range-456"
        }
        """)
    }

    @Test("Tool Use encoding/decoding - single line")
    func test_toolUseEncodingDecodingSingleLine() throws {
      let tool = ReadFileTool()
      let lineRange = ReadFileTool.Use.Input.Range(start: 25, end: 25)
      let input = ReadFileTool.Use.Input(
        path: "/config/settings.json",
        lineRange: lineRange)
      let use = tool.use(toolUseId: "read-single-789", input: input, isInputComplete: true, context: toolExecutionContext)

      try testDecodingEncodingWithTool(of: use, tool: tool, """
        {
          "callingTool": "read_file",
          "context": {
            "threadId": "mock-thread-id"
          },
          "input": {
            "lineRange": {
              "end": 25,
              "start": 25
            },
            "path": "/config/settings.json"
          },
          "internalState": {
            "lineRange" : {
              "end" : 25,
              "start" : 25
            },
            "path" : "/config/settings.json"
          },
          "isInputComplete": true,
          "status": {
            "status": "notStarted"
          },
          "toolUseId": "read-single-789"
        }
        """)
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
  }

}
