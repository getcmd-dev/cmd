// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
let lsPath = "/path/to/some-directory"
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      LSToolUseView(toolUse: LSToolUseViewModel(
        status: .Just(.running),
        input: .init(path: lsPath, ignore: nil)))
      LSToolUseView(toolUse: LSToolUseViewModel(status: .Just(.notStarted), input: .init(path: lsPath, ignore: nil)))
      LSToolUseView(toolUse: LSToolUseViewModel(
        status: .Just(.completed(.success(.init(
          content: """
            - /Users/guigui/dev/cmd.git/cc-provider/
              - app/
                - modules/
                  - plugins/
                    - tools/
                      - ClaudeCodeTools/
                        - Tests/
                          - ClaudeCodeReadToolTests.swift
                          - ClaudeCodeReadToolEncodingTests.swift
            """)))),
        input: .init(path: lsPath, ignore: nil)))

      LSToolUseView(toolUse: LSToolUseViewModel(
        status: .Just(.completed(.success(.init(
          content: longLSContent)))),
        input: .init(path: lsPath, ignore: nil)))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}

let longLSContent = """
  - /Users/guigui/dev/cmd.git/cc-provider/
    - app/
      - modules/
        - plugins/
          - tools/
            - ReadFileTool/
              - Module.swift
              - Sources/
                - Content.swift
                - ReadFileTool+Codable.swift
                - ReadFileTool.swift
                - ReadFileToolView+Preview.swift
                - ReadFileToolView.swift
              - Tests/
                - ReadFileToolEncodingTests.swift
                - ReadFileToolTests.swift
            - ClaudeCodeTools/
              - Sources/
                - Read/
                  - ClaudeCodeReadTool+Codable.swift
                  - ClaudeCodeReadTool.swift
                  - ClaudeCodeReadToolView+Preview.swift
                  - ClaudeCodeReadToolView.swift
                  - ReadContent.swift
                - LS/
                  - ClaudeCodeLSTool+Codable.swift
                  - ClaudeCodeLSTool.swift
                  - ClaudeCodeLSToolView+Preview.swift
                  - ClaudeCodeLSToolView.swift
            - LSTool/
              - Module.swift
              - Sources/
                - LSTool+Codable.swift
                - LSTool.swift
                - LSToolView+Preview.swift
                - LSToolView.swift
              - Tests/
                - LSToolEncodingTests.swift
                - LSToolTests.swift
  """
#endif