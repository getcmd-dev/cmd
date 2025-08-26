// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import Foundation
import JSONFoundation
import Testing
import ToolFoundation
@testable import ClaudeCodeTools

@Suite("ClaudeCodeWebSearchTool Tests")
struct ClaudeCodeWebSearchToolTests {

  @Test("Parse WebSearch output with exact format from user example")
  func testParseWebSearchOutput() async throws {
    // This is the exact output format provided by the user
    let output = """
      Web search results for query: "MCP HTTP streaming specifications"

      I'll search for information about MCP HTTP streaming specifications.

      Links: [{"title":"HTTP Stream Transport | MCP Framework","url":"https://mcp-framework.com/docs/Transports/http-stream-transport/"},{"title":"MCP's New Transport Layer - A Deep Dive into the Streamable HTTP Protocol | Claude MCP Blog","url":"https://www.claudemcp.com/blog/mcp-streamable-http"},{"title":"Transports - Model Context Protocol","url":"https://modelcontextprotocol.io/specification/2025-03-26/basic/transports"},{"title":"Bringing streamable HTTP transport and Python language support to MCP servers","url":"https://blog.cloudflare.com/streamable-http-mcp-servers-python/"},{"title":"HTTP Quickstart | MCP Framework","url":"https://mcp-framework.com/docs/http-quickstart/"},{"title":"Transports – Model Context Protocol Specification","url":"https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/transports/"},{"title":"artificial intelligence - Is MCP HTTP streaming actually streaming? - Stack Overflow","url":"https://stackoverflow.com/questions/79658818/is-mcp-http-streaming-actually-streaming"},{"title":"GitHub - invariantlabs-ai/mcp-streamable-http: Example implementation of MCP Streamable HTTP client/server in Python and TypeScript.","url":"https://github.com/invariantlabs-ai/mcp-streamable-http"},{"title":"From stdio to HTTP SSE: Host Your MCP Server with APISIX API Gateway | Apache APISIX® -- Cloud-Native API Gateway and AI Gateway","url":"https://apisix.apache.org/blog/2025/04/21/host-mcp-server-with-api-gateway/"},{"title":"Support new MCP Streaming HTTP transport · Issue #54 · stacklok/toolhive","url":"https://github.com/stacklok/toolhive/issues/54"}]

      Based on the search results, I can provide you with comprehensive information about the MCP HTTP streaming specifications.

      ## MCP HTTP Streaming Specifications Overview

      The Model Context Protocol (MCP) has introduced a new transport mechanism called "Streamable HTTP transport" which replaces the deprecated HTTP+SSE transport from protocol version 2024-11-05. The current protocol revision is 2025-03-26.

      ### Key Features

      The HTTP Stream Transport provides a modern, flexible transport layer that supports both batch responses and streaming via Server-Sent Events (SSE). The main features include:

      - Single Endpoint: Uses a single HTTP endpoint for all MCP communication
      - Multiple Response Modes: Support for both batch (JSON) and streaming (SSE) responses
      - Session Management: Built-in session tracking and management
      - Resumability: Support for resuming broken SSE connections
      - Authentication: Comprehensive authentication support
      - CORS: Flexible CORS configuration for web applications

      ### Technical Specifications

      #### Endpoint Requirements
      The server MUST provide a single HTTP endpoint path (hereafter referred to as the MCP endpoint) that supports both POST and GET methods. For example, this could be a URL like https://example.com/mcp.

      #### Client Request Requirements
      For POST requests:
      - The client MUST use HTTP POST to send JSON-RPC messages to the MCP endpoint
      - The client MUST include an Accept header, listing both application/json and text/event-stream as supported content types
      - The body of the POST request MUST be one of the following: A single JSON-RPC request, notification, or response · An array batching one or more requests and/or notifications

      For GET requests:
      - The client MAY issue an HTTP GET to the MCP endpoint. This can be used to open an SSE stream, allowing the server to communicate to the client, without the client first sending data via HTTP POST
      - The client MUST include an Accept header, listing text/event-stream as a supported content type

      #### Server Response Requirements
      - If the server accepts the input, the server MUST return HTTP status code 202 Accepted with no body
      - If the server cannot accept the input, it MUST return an HTTP error status code (e.g., 400 Bad Request)
      - If the input contains any number of JSON-RPC requests, the server MUST either return Content-Type: text/event-stream, to initiate an SSE stream, or Content-Type: application/json, to return one JSON object

      ### Advantages Over Previous Transport

      The new Streamable HTTP transport addresses these challenges by enabling: Communication through a single endpoint: All MCP interactions now flow through one endpoint, eliminating the need to manage separate endpoints for requests and responses, reducing complexity. Bi-directional communication: Servers can send notifications and requests back to clients on the same connection, enabling the server to prompt for additional information or provide real-time updates.

      ### Backward Compatibility

      Our implementation allows your MCP server to simultaneously handle both the new Streamable HTTP transport and the existing SSE transport, maintaining backward compatibility with all remote MCP clients.

      For clients to determine which transport a server supports:
      1. Attempt to POST an InitializeRequest to the server URL, with an Accept header as defined above: If it succeeds, the client can assume this is a server supporting the new Streamable HTTP transport
      2. If it fails with an HTTP 4xx status code (e.g., 405 Method Not Allowed or 404 Not Found): Issue a GET request to the server URL, expecting that this will open an SSE stream and return an endpoint event as the first event

      ### Implementation Notes

      - JSON-RPC messages MUST be UTF-8 encoded
      - Servers MUST validate the Origin header on all incoming connections to prevent DNS rebinding attacks
      - To avoid message loss due to disconnection, the server MAY make the stream resumable
      - To cancel, the client SHOULD explicitly send an MCP CancelledNotification

      The Streamable HTTP transport represents a significant improvement in MCP's architecture, simplifying remote communication while maintaining support for both simple request-response patterns and complex streaming scenarios.
      """

    // Create the tool use
    let tool = ClaudeCodeWebSearchTool()
    let use = ClaudeCodeWebSearchTool.Use(
      callingTool: tool,
      toolUseId: "test-id",
      input: .init(query: "MCP HTTP streaming specifications", allowed_domains: nil, blocked_domains: nil),
      context: .init())

    // Test receiving the output
    try use.receive(output: .string(output))

    // Wait for the status to be updated
    var finalStatus: ToolUseExecutionStatus<ClaudeCodeWebSearchTool.Use.Output>?
    for await status in use.status.futureUpdates {
      finalStatus = status
      if case .completed = status {
        break
      }
    }

    // Verify the results
    guard case .completed(.success(let result)) = finalStatus else {
      #expect(Bool(false), "Expected successful completion")
      return
    }

    // Check that we parsed all 10 links correctly
    #expect(result.links.count == 10)

    // Verify first few links
    #expect(result.links[0].title == "HTTP Stream Transport | MCP Framework")
    #expect(result.links[0].url == "https://mcp-framework.com/docs/Transports/http-stream-transport/")

    #expect(result.links[1]
      .title == "MCP's New Transport Layer - A Deep Dive into the Streamable HTTP Protocol | Claude MCP Blog")
    #expect(result.links[1].url == "https://www.claudemcp.com/blog/mcp-streamable-http")

    #expect(result.links[2].title == "Transports - Model Context Protocol")
    #expect(result.links[2].url == "https://modelcontextprotocol.io/specification/2025-03-26/basic/transports")

    // Verify the content starts with expected text
    #expect(result.content.contains("Based on the search results"))
    #expect(result.content.contains("MCP HTTP Streaming Specifications Overview"))
    #expect(result.content.contains("The Model Context Protocol (MCP) has introduced a new transport mechanism"))
  }

  @Test("Parse WebSearch output with empty links")
  func testParseWebSearchOutputEmptyLinks() async throws {
    let output = """
      Web search results for query: "test query"

      Links: []

      No results found for the search query.
      """

    let tool = ClaudeCodeWebSearchTool()
    let use = ClaudeCodeWebSearchTool.Use(
      callingTool: tool,
      toolUseId: "test-id",
      input: .init(query: "test query", allowed_domains: nil, blocked_domains: nil),
      context: .init())

    try use.receive(output: .string(output))

    var finalStatus: ToolUseExecutionStatus<ClaudeCodeWebSearchTool.Use.Output>?
    for await status in use.status.futureUpdates {
      finalStatus = status
      if case .completed = status {
        break
      }
    }

    guard case .completed(.success(let result)) = finalStatus else {
      #expect(Bool(false), "Expected successful completion")
      return
    }

    #expect(result.links.isEmpty)
    #expect(result.content == "No results found for the search query.")
  }

  @Test("Parse WebSearch output with malformed input")
  func testParseWebSearchOutputMalformed() async throws {
    let output = "This is not a valid WebSearch output"

    let tool = ClaudeCodeWebSearchTool()
    let use = ClaudeCodeWebSearchTool.Use(
      callingTool: tool,
      toolUseId: "test-id",
      input: .init(query: "test", allowed_domains: nil, blocked_domains: nil),
      context: .init())

    #expect(throws: (any Error).self) {
      try use.receive(output: .string(output))
    }
  }

  @Test("Tool schema validation")
  func testToolSchema() throws {
    let tool = ClaudeCodeWebSearchTool()

    #expect(tool.name == "claude_code_WebSearch")
    #expect(tool.displayName == "WebSearch (Claude Code)")
    #expect(tool.isAvailable(in: .agent))

    // Verify the input schema structure
    guard
      case .object(let schema) = tool.inputSchema,
      case .string("object") = schema["type"],
      case .object(let properties) = schema["properties"],
      case .array(let required) = schema["required"]
    else {
      #expect(Bool(false), "Invalid schema structure")
      return
    }

    // Check required fields
    #expect(required.count == 1)
    #expect(required.contains(.string("query")))

    // Check properties
    #expect(properties.keys.contains("query"))
    #expect(properties.keys.contains("allowed_domains"))
    #expect(properties.keys.contains("blocked_domains"))
  }
}
