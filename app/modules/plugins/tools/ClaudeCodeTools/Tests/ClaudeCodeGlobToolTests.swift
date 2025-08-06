// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import JSONFoundation
import SwiftTesting
import Testing
@testable import ClaudeCodeTools

struct ClaudeCodeGlobToolTests {

  @Test
  func handlesExternalOutputCorrectly() async throws {
    let toolUse = ClaudeCodeGlobTool().use(
      toolUseId: "123",
      input: .init(pattern: "**/*.swift", path: nil),
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate external output from Claude Code
    let output = testGlobOutput

    try toolUse.receive(output: output)
    let result = try await toolUse.output

    #expect(result.files.count == 5)
    #expect(result.files
      .contains(
        "/Users/guigui/dev/cmd.git/cc-provider/app/modules/plugins/tools/ClaudeCodeTools/Tests/ClaudeCodeGlobToolTests.swift"))
    #expect(result.files
      .contains(
        "/Users/guigui/dev/cmd.git/cc-provider/app/modules/plugins/tools/ClaudeCodeTools/Tests/ClaudeCodeReadToolTests.swift"))
  }

  @Test
  func handlesEmptyOutput() async throws {
    let toolUse = ClaudeCodeGlobTool().use(
      toolUseId: "456",
      input: .init(pattern: "**/*.nonexistent", path: "/some/path"),
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate empty output
    let output = ""

    try toolUse.receive(output: output)
    let result = try await toolUse.output

    #expect(result.files.isEmpty)
  }

  private let testGlobOutput = """
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/plugins/tools/ClaudeCodeTools/Tests/ClaudeCodeReadToolTests.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/plugins/tools/ClaudeCodeTools/Tests/ClaudeCodeGlobToolTests.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/plugins/tools/ClaudeCodeTools/Sources/Read/ClaudeCodeReadTool.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/plugins/tools/ClaudeCodeTools/Sources/Glob/ClaudeCodeGlobTool.swift
    /Users/guigui/dev/cmd.git/cc-provider/app/modules/plugins/tools/ClaudeCodeTools/Sources/Read/ClaudeCodeReadToolView.swift
    """
}
