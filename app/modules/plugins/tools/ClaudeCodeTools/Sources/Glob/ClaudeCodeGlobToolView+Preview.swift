// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      let input1 = ClaudeCodeGlobTool.Use.Input(pattern: "**/*.swift", path: nil)
      GlobToolUseView(toolUse: GlobToolUseViewModel(
        status: .Just(.running(input: input1)),
        input: input1))

      let input2 = ClaudeCodeGlobTool.Use.Input(pattern: "src/**/*.ts", path: "/Users/user/project")
      GlobToolUseView(toolUse: GlobToolUseViewModel(
        status: .Just(.notStarted(input: input2)),
        input: input2))

      let input3 = ClaudeCodeGlobTool.Use.Input(pattern: "**/*.swift", path: nil)
      GlobToolUseView(toolUse: GlobToolUseViewModel(
        status: .Just(.completed(input: input3, result: .success(.init(
          files: [
            "/Users/user/project/src/main.swift",
            "/Users/user/project/src/utils/helpers.swift",
            "/Users/user/project/src/models/User.swift",
            "/Users/user/project/src/views/ContentView.swift",
            "/Users/user/project/tests/MainTests.swift",
          ])))),
        input: input3))

      let input4 = ClaudeCodeGlobTool.Use.Input(pattern: "**/*.txt", path: nil)
      GlobToolUseView(toolUse: GlobToolUseViewModel(
        status: .Just(.completed(input: input4, result: .success(.init(
          files: Array(0..<30).map { "/Users/user/project/file\($0).txt" })))),
        input: input4))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
