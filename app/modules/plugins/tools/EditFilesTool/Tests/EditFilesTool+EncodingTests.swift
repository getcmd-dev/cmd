// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatServiceInterface
import Dependencies
import Foundation
import FoundationInterfaces
import JSONFoundation
import SwiftTesting
import Testing
import ToolFoundation
import XcodeObserverServiceInterface
@testable import EditFilesTool

// MARK: - EditFilesToolEncodingTests

struct EditFilesToolEncodingTests {

  // MARK: - Tool Use Encoding/Decoding Tests

  @Test("Tool Use encoding/decoding - single file edit")
  func test_toolUseEncodingDecodingSingleFile() throws {
    let tool = EditFilesTool(shouldAutoApply: false)

    let fileChange = EditFilesTool.Use.Input.FileChange(
      path: "/project/README.md",
      isNewFile: false,
      changes: [
        EditFilesTool.Use.Input.FileChange.Change(
          search: "# Old Title",
          replace: "# New Title"),
      ])

    let input = EditFilesTool.Use.Input(files: [fileChange])
    let data = try JSONEncoder().encode(input)
    let files = [
      fileChange.path: "# Old Title",
    ]

    try withDependencies {
      $0.chatContextRegistry = MockChatContextRegistryService([
        "mock-thread-id": MockChatThreadContext(knownFilesContent: files),
      ])
      $0.xcodeObserver = MockXcodeObserver(fileManager: MockFileManager(files: files))
    } operation: {
      let use = try tool.use(toolUseId: "edit-123", input: data, isInputComplete: true, context: toolExecutionContext)

      try testDecodingEncodingWithTool(of: use, tool: tool, """
        {
          "callingTool" : "suggest_files_changes",
          "context" : {
            "threadId": "mock-thread-id"
          },
          "input" : {
            "files" : [
              {
                "changes" : [
                  {
                    "replace" : "# New Title",
                    "search" : "# Old Title"
                  }
                ],
                "isNewFile" : false,
                "path" : "\\/project\\/README.md"
              }
            ]
          },
          "internalState" : null,
          "isInputComplete" : true,
          "status" : {
            "status" : "notStarted"
          },
          "toolUseId" : "edit-123"
        }
        """)
    }
  }

  @Test("Tool Use encoding/decoding - new file creation")
  func test_toolUseEncodingDecodingNewFile() throws {
    let tool = EditFilesTool(shouldAutoApply: false)

    let fileChange = EditFilesTool.Use.Input.FileChange(
      path: "/config/settings.json",
      isNewFile: true,
      changes: [
        EditFilesTool.Use.Input.FileChange.Change(
          search: "",
          replace: "{\"environment\": \"production\"}"),
      ])

    let input = EditFilesTool.Use.Input(files: [fileChange])
    let data = try JSONEncoder().encode(input)

    let use = try tool.use(toolUseId: "edit-new-456", input: data, isInputComplete: true, context: toolExecutionContext)

    try testDecodingEncodingWithTool(of: use, tool: tool, """
      {
        "callingTool" : "suggest_files_changes",
        "context" : {
          "threadId": "mock-thread-id"
        },
        "input" : {
          "files" : [
            {
              "changes" : [
                {
                  "replace" : "{\\"environment\\": \\"production\\"}",
                  "search" : ""
                }
              ],
              "isNewFile" : true,
              "path" : "/config/settings.json"
            }
          ]
        },
        "internalState" : null,
        "isInputComplete" : true,
        "status" : {
          "status" : "notStarted"
        },
        "toolUseId" : "edit-new-456"
      }
      """)
  }

  @Test("Tool Use encoding/decoding - multiple files")
  func test_toolUseEncodingDecodingMultipleFiles() throws {
    let tool = EditFilesTool(shouldAutoApply: false)

    let fileChanges = [
      EditFilesTool.Use.Input.FileChange(
        path: "/src/constants.swift",
        isNewFile: false,
        changes: [
          EditFilesTool.Use.Input.FileChange.Change(
            search: "let API_URL = \"dev.example.com\"",
            replace: "let API_URL = \"api.example.com\""),
        ]),
      EditFilesTool.Use.Input.FileChange(
        path: "/tests/NewTest.swift",
        isNewFile: true,
        changes: [
          EditFilesTool.Use.Input.FileChange.Change(
            search: "",
            replace: "import XCTest\n\nclass NewTest: XCTestCase {\n    // Test implementation\n}"),
        ]),
    ]

    let input = EditFilesTool.Use.Input(files: fileChanges)
    let data = try JSONEncoder().encode(input)

    let files = [
      fileChanges[0].path: "let API_URL = \"dev.example.com\"",
    ]

    try withDependencies {
      $0.chatContextRegistry = MockChatContextRegistryService([
        "mock-thread-id": MockChatThreadContext(knownFilesContent: files),
      ])
      $0.xcodeObserver = MockXcodeObserver(fileManager: MockFileManager(files: files))
    } operation: {
      let use = try tool.use(toolUseId: "edit-multi-789", input: data, isInputComplete: true, context: toolExecutionContext)
      try testDecodingEncodingWithTool(of: use, tool: tool, """
        {
          "callingTool" : "suggest_files_changes",
          "context" : {
            "threadId": "mock-thread-id"
          },
          "input" : {
            "files" : [
              {
                "changes" : [
                  {
                    "replace" : "let API_URL = \\"api.example.com\\"",
                    "search" : "let API_URL = \\"dev.example.com\\""
                  }
                ],
                "isNewFile" : false,
                "path" : "/src/constants.swift"
              },
              {
                "changes" : [
                  {
                    "replace" : "import XCTest\\n\\nclass NewTest: XCTestCase {\\n    \\/\\/ Test implementation\\n}",
                    "search" : ""
                  }
                ],
                "isNewFile" : true,
                "path" : "/tests/NewTest.swift"
              }
            ]
          },
          "internalState" : null,
          "isInputComplete" : true,
          "status" : {
            "status" : "notStarted"
          },
          "toolUseId" : "edit-multi-789"
        }
        """)
    }
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
