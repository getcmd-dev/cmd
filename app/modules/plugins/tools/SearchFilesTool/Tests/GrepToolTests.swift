// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import JSONFoundation
import SwiftTesting
import Testing
@testable import SearchFilesTool

struct GrepToolTests {

  @Test
  func handlesExternalOutputCorrectly() async throws {
    let inputJSON = """
      {
        "pattern": "JSON",
        "output_mode": "files_with_matches",
        "projectRoot": "/Users/guigui/dev/cmd.git/cc-provider/app"
      }
      """

    let input = try JSONDecoder().decode(ClaudeCodeGrepInput.self, from: inputJSON.data(using: .utf8)!)

    let toolUse = ClaudeCodeGrepTool().use(
      toolUseId: "123",
      input: input,
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/Users/guigui/dev/cmd.git/cc-provider/app")))

    toolUse.startExecuting()

    // Simulate external output
    let externalOutput = testOutput

    try toolUse.receive(output: externalOutput)
    let result = try await toolUse.output.results.map(\.path)
    #expect(result == [
      "/Users/guigui/dev/cmd.git/cc-provider/app/modules/serviceInterfaces/ServerServiceInterface/Sources/sendMessageSchema.generated.swift",
      "/Users/guigui/dev/cmd.git/cc-provider/app/modules/services/ChatHistoryService/Sources/Serialization.swift",
      "/Users/guigui/dev/cmd.git/cc-provider/app/modules/foundations/JSONFoundation/Sources/JSON.swift",
      "/Users/guigui/dev/cmd.git/cc-provider/app/modules/foundations/LLMFoundation/Sources/LLMProvider.swift",
      "/Users/guigui/dev/cmd.git/cc-provider/app/modules/services/LLMService/Sources/JSON+partialParsing.swift",
      "/Users/guigui/dev/cmd.git/cc-provider/app/modules/services/ChatHistoryService/Sources/AttachmentSerializer.swift",
      "/Users/guigui/dev/cmd.git/cc-provider/app/modules/serviceInterfaces/ServerServiceInterface/Tests/ErrorParsingTests.swift",
      "/Users/guigui/dev/cmd.git/cc-provider/app/modules/foundations/ToolFoundation/Sources/Encoding.swift",
    ])
  }

  private let testOutput = """
    Found 8 files
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/serviceInterfaces/ServerServiceInterface/Sources/sendMessageSchema.generated.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/services/ChatHistoryService/Sources/Serialization.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/foundations/JSONFoundation/Sources/JSON.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/foundations/LLMFoundation/Sources/LLMProvider.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/services/LLMService/Sources/JSON+partialParsing.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/services/ChatHistoryService/Sources/AttachmentSerializer.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/serviceInterfaces/ServerServiceInterface/Tests/ErrorParsingTests.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/foundations/ToolFoundation/Sources/Encoding.swift
    """
}
