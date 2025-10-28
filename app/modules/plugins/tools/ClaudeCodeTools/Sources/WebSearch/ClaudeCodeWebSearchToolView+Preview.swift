// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI
import ToolFoundation

#if DEBUG
#Preview("WebSearch - Not Started") {
  let input = ClaudeCodeWebSearchTool.Use.Input(
    query: "MCP HTTP streaming specifications",
    allowedDomains: nil,
    blockedDomains: nil)
  let use = ClaudeCodeWebSearchTool.Use(
    callingTool: .init(),
    toolUseId: "preview",
    inputResult: .success(input),
    context: ToolExecutionContext(),
    initialStatus: .notStarted(input: input))
  use.body
    .padding()
    .frame(width: 500)
}

#Preview("WebSearch - Running") {
  let input = ClaudeCodeWebSearchTool.Use.Input(
    query: "SwiftUI best practices 2025",
    allowedDomains: ["developer.apple.com"],
    blockedDomains: nil)
  let use = ClaudeCodeWebSearchTool.Use(
    callingTool: .init(),
    toolUseId: "preview",
    inputResult: .success(input),
    context: ToolExecutionContext(),
    initialStatus: .running(input: input))
  use.body
    .padding()
    .frame(width: 500)
}

#Preview("WebSearch - Success") {
  let input = ClaudeCodeWebSearchTool.Use.Input(
    query: "MCP HTTP streaming specifications",
    allowedDomains: nil,
    blockedDomains: nil)
  let use = ClaudeCodeWebSearchTool.Use(
    callingTool: .init(),
    toolUseId: "preview",
    inputResult: .success(input),
    context: ToolExecutionContext(),
    initialStatus: .completed(
      input: input,
      result: .success(.init(
        links: [
          .init(
            title: "HTTP Stream Transport | MCP Framework",
            url: "https://mcp-framework.com/docs/Transports/http-stream-transport/"),
          .init(
            title: "MCP's New Transport Layer - A Deep Dive into the Streamable HTTP Protocol | Claude MCP Blog",
            url: "https://www.claudemcp.com/blog/mcp-streamable-http"),
          .init(
            title: "Transports - Model Context Protocol",
            url: "https://modelcontextprotocol.io/specification/2025-03-26/basic/transports"),
        ],
        content: "The Model Context Protocol (MCP) has introduced a new transport mechanism called \"Streamable HTTP transport\" which replaces the deprecated HTTP+SSE transport..."))))
  use.body
    .padding()
    .frame(width: 500)
}

#Preview("WebSearch - Error") {
  let input = ClaudeCodeWebSearchTool.Use.Input(
    query: "test query",
    allowedDomains: nil,
    blockedDomains: ["example.com"])
  let use = ClaudeCodeWebSearchTool.Use(
    callingTool: .init(),
    toolUseId: "preview",
    inputResult: .success(input),
    context: ToolExecutionContext(),
    initialStatus: .completed(input: input, result: .failure(NSError(
      domain: "WebSearchError",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey: "Failed to connect to search service. The operation couldn't be completed due to a network timeout error.",
      ]))))
  use.body
    .padding()
    .frame(width: 500)
}
#endif
