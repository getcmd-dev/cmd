// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
let path = "/path/to/some-file.txt"
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(path: path, lineRange: .init(start: 1, end: 10)), projectRoot: nil))
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.notStarted),
        input: .init(path: path, lineRange: nil),
        projectRoot: nil))
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          content: """
            import Foundation

            func helloWorld() {
                print("Hello, world!")
            }

            // This is an example file content
            // for the ReadFileTool preview
            """,
          uri: "/path/to/some-file.txt")))),
        input: .init(path: path, lineRange: nil), projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          content: longContent,
          uri: "/path/to/some-file.swift")))),
        input: .init(path: path, lineRange: nil), projectRoot: nil))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
