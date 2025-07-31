// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import EditFilesTool
import Foundation
import JSONFoundation
import SwiftTesting
import ToolFoundation

@Suite("ClaudeCodeWriteTool Tests")
struct ClaudeCodeWriteToolTests {

  @Test("Tool has correct name")
  func testToolName() {
    let tool = ClaudeCodeWriteTool()
    #expect(tool.name == "Write")
  }

  @Test("Tool has correct display name")
  func testDisplayName() {
    let tool = ClaudeCodeWriteTool()
    #expect(tool.displayName == "Write (Claude Code)")
  }

  @Test("Tool input schema is valid")
  func testInputSchema() {
    let tool = ClaudeCodeWriteTool()
    let schema = tool.inputSchema
    
    // Verify the schema has the expected structure
    guard case .object(let properties) = schema else {
      Issue.record("Schema should be an object")
      return
    }
    
    #expect(properties["type"] == .string("object"))
    
    guard case .object(let props) = properties["properties"] else {
      Issue.record("Properties should be an object")
      return
    }
    
    #expect(props["file_path"] != nil)
    #expect(props["content"] != nil)
  }

  @Test("Tool input can be decoded")
  func testInputDecoding() throws {
    let jsonString = """
    {
      "file_path": "/path/to/test.swift",
      "content": "print(\\"Hello, World!\\")"
    }
    """
    
    let jsonData = jsonString.data(using: .utf8)!
    let input = try JSONDecoder().decode(ClaudeCodeWriteTool.Use.Input.self, from: jsonData)
    
    #expect(input.file_path == "/path/to/test.swift")
    #expect(input.content == "print(\"Hello, World!\")")
  }

  @Test("Tool use creates appropriate edit files input")
  func testToolUseCreatesEditFilesInput() {
    let tool = ClaudeCodeWriteTool()
    let context = ToolExecutionContext(project: nil, projectRoot: URL(filePath: "/project/root"))
    
    let input = ClaudeCodeWriteTool.Use.Input(
      file_path: "/project/root/test.swift",
      content: "print(\"Hello, World!\")"
    )
    
    let toolUse = ClaudeCodeWriteTool.Use(
      callingTool: tool,
      toolUseId: "test-123",
      input: input,
      context: context
    )
    
    // Check that the tool use creates the appropriate view
    let body = toolUse.body
    #expect(body != nil)
  }

  @Test("Tool is available in all chat modes")  
  func testToolAvailability() {
    let tool = ClaudeCodeWriteTool()
    
    #expect(tool.isAvailable(in: .agent))
    #expect(tool.isAvailable(in: .ask))
  }
}