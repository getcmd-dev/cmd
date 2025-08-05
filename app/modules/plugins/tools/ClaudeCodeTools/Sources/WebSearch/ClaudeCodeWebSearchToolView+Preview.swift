// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI
import ToolFoundation

#if DEBUG
#Preview("WebSearch - Not Started") {
  let use = ClaudeCodeWebSearchTool.Use(
    callingTool: .init(),
    toolUseId: "preview",
    input: .init(
      query: "MCP HTTP streaming specifications",
      allowed_domains: nil,
      blocked_domains: nil),
    context: ToolExecutionContext(),
    initialStatus: .notStarted)
  return use.body
    .padding()
    .frame(width: 500)
}

#Preview("WebSearch - Running") {
  let use = ClaudeCodeWebSearchTool.Use(
    callingTool: .init(),
    toolUseId: "preview",
    input: .init(
      query: "SwiftUI best practices 2025",
      allowed_domains: ["developer.apple.com"],
      blocked_domains: nil),
    context: ToolExecutionContext(),
    initialStatus: .running)
  return use.body
    .padding()
    .frame(width: 500)
}

#Preview("WebSearch - Success") {
  let use = ClaudeCodeWebSearchTool.Use(
    callingTool: .init(),
    toolUseId: "preview",
    input: .init(
      query: "MCP HTTP streaming specifications",
      allowed_domains: nil,
      blocked_domains: nil),
    context: ToolExecutionContext(),
    initialStatus: .completed(.success(.init(
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
  return use.body
    .padding()
    .frame(width: 500)
}

#Preview("WebSearch - Error") {
  let use = ClaudeCodeWebSearchTool.Use(
    callingTool: .init(),
    toolUseId: "preview",
    input: .init(
      query: "test query",
      allowed_domains: nil,
      blocked_domains: ["example.com"]),
    context: ToolExecutionContext(),
    initialStatus: .completed(.failure(NSError(
      domain: "WebSearchError",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey: "Failed to connect to search service. The operation couldn't be completed due to a network timeout error.",
      ]))))
  return use.body
    .padding()
    .frame(width: 500)
}
#endif
