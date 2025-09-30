// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftTesting
import Testing
import ToolFoundation
@testable import MCPService

enum MCPToolTests {
  struct MCPToolPresistenceTests {
    @Test
    func test_mcpToolCanBeDecodedAndEncoded() throws {
      let tool = MCPTool(
        tool: .init(name: "test-tool", description: "Test tool", inputSchema: .object([:])),
        client: .init(name: "test-client", version: "1.0.0"),
        serverName: "test-server")

      try testDecodingEncodingWithTool(
        of: tool.use(toolUseId: "tool-use-id", input: [:], isInputComplete: true, context: toolExecutionContext),
        tool: tool,
        """
        {
          "callingTool" : "mcp__test_server__test_tool",
          "context" : {
            "threadId" : "mock-thread-id"
          },
          "input" : {

          },
          "internalState" : null,
          "isInputComplete" : true,
          "status" : {
            "status" : "notStarted"
          },
          "toolUseId" : "tool-use-id"
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
