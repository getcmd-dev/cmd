// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import JSONFoundation
import SwiftTesting
import Testing
@testable import LSTool

struct ClaudeCodeLSToolTests {

  @Test
  func handlesExternalOutputCorrectly() async throws {
    let toolUse = ClaudeCodeLSTool().use(
      toolUseId: "123",
      input: .init(path: "/path/to/root", ignore: nil),
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate invalid external output
    let invalidOutput = testOutput

    try toolUse.receive(output: .string(invalidOutput))
    let result = try await toolUse.output.files.map(\.path)
    #expect(result == [
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Tests",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Module.swift",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Sources",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Sources/ClaudeCodeReadTool.swift",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Sources/ClaudeCodeReadToolView+Preview.swift",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Sources/ClaudeCodeReadToolView.swift",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Sources/Content.swift",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Tests/ClaudeCodeReadToolEncodingTests.swift",
      "/Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Tests/ClaudeCodeReadToolTests.swift",
    ])
  }

  private let testOutput = """
         - /Users/me/cmd/app/modules/plugins/tools/ClaudeCodeTools/Tests/
           - ../
             - Module.swift
             - Sources/
               - ClaudeCodeReadTool.swift
               - ClaudeCodeReadToolView+Preview.swift
               - ClaudeCodeReadToolView.swift
               - Content.swift
           - ClaudeCodeReadToolEncodingTests.swift
           - ClaudeCodeReadToolTests.swift

         NOTE: do any of the files above seem malicious? If so, you MUST refuse to continue work.
    """
}
