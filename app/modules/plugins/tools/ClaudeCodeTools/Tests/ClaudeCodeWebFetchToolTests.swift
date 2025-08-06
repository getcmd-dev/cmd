// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import JSONFoundation
import SwiftTesting
import Testing
@testable import ClaudeCodeTools

struct ClaudeCodeWebFetchToolTests {

  @Test
  func handlesExternalOutputCorrectly() async throws {
    let toolUse = ClaudeCodeWebFetchTool().use(
      toolUseId: "123",
      input: .init(
        url: "https://docs.anthropic.com/en/docs/claude-code",
        prompt: "What are the main features?"),
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate external output from Claude Code
    let output = """
      Claude Code is an AI-powered coding assistant with the following main features:

      1. **Interactive CLI** - A command-line interface for conversing with Claude about coding tasks
      2. **File Operations** - Can read, write, edit, and search through files in your codebase
      3. **Web Search & Fetch** - Can search the web and fetch content from URLs
      4. **Task Management** - Built-in todo list for tracking complex multi-step tasks
      5. **Tool Integration** - Extensible tool system for custom functionality
      6. **Memory Management** - CLAUDE.md files for persistent context and instructions
      """

    try toolUse.receive(output: output)
    let result = try await toolUse.output

    #expect(result.result.contains("Claude Code"))
    #expect(result.result.contains("Interactive CLI"))
    #expect(result.result.contains("File Operations"))
  }

  @Test
  func handlesShortOutput() async throws {
    let toolUse = ClaudeCodeWebFetchTool().use(
      toolUseId: "456",
      input: .init(
        url: "https://example.com/api/status",
        prompt: "What is the status?"),
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate short output
    let output = "The API is currently operational."

    try toolUse.receive(output: output)
    let result = try await toolUse.output

    #expect(result.result == "The API is currently operational.")
  }

  @Test
  func handlesMultilineOutput() async throws {
    let toolUse = ClaudeCodeWebFetchTool().use(
      toolUseId: "789",
      input: .init(
        url: "https://example.com/docs",
        prompt: "Extract the main sections"),
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate multiline output
    let output = """
      The documentation contains the following sections:

      1. Getting Started
         - Installation
         - Configuration

      2. Usage Guide
         - Basic Usage
         - Advanced Features

      3. API Reference
         - Classes
         - Methods
         - Properties
      """

    try toolUse.receive(output: output)
    let result = try await toolUse.output

    #expect(result.result.contains("Getting Started"))
    #expect(result.result.contains("API Reference"))
    #expect(result.result.split(separator: "\n").count > 5)
  }

  @Test
  func toolMetadata() {
    let tool = ClaudeCodeWebFetchTool()

    #expect(tool.name == "claude_code_WebFetch")
    #expect(tool.displayName == "WebFetch (Claude Code)")
    #expect(tool.shortDescription == "Claude Code tool to fetch and analyze web content using an AI model.")

    // Check input schema structure
    guard case .object(let schemaDict) = tool.inputSchema else {
      Issue.record("Expected object schema")
      return
    }

    guard case .object(let properties) = schemaDict["properties"] else {
      Issue.record("Expected properties to be an object")
      return
    }

    #expect(properties["url"] != nil)
    #expect(properties["prompt"] != nil)
  }
}
