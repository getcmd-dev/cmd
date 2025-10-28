// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
let path = "/path/to/some-file.txt"
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      let input1 = ReadFileTool.Use.Input(path: path, lineRange: .init(start: 1, end: 10))
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running(input: input1)),
        input: input1, projectRoot: nil))

      let input2 = ReadFileTool.Use.Input(path: path, lineRange: nil)
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.notStarted(input: input2)),
        input: input2,
        projectRoot: nil))

      let input3 = ReadFileTool.Use.Input(path: path, lineRange: nil)
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(input: input3, result: .success(.init(
          content: """
            import Foundation

            func helloWorld() {
                print("Hello, world!")
            }

            // This is an example file content
            // for the ReadFileTool preview
            """,
          uri: "/path/to/some-file.txt")))),
        input: input3, projectRoot: nil))

      let input4 = ReadFileTool.Use.Input(path: path, lineRange: nil)
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(input: input4, result: .success(.init(
          content: longContent,
          uri: "/path/to/some-file.swift")))),
        input: input4, projectRoot: nil))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
