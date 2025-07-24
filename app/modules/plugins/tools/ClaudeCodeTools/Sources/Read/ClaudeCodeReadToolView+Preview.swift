// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
let readPath = "/path/to/some-file.txt"
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      ReadToolUseView(toolUse: ReadToolUseViewModel(
        status: .Just(.running),
        input: .init(file_path: readPath, offset: 1, limit: 10)))
      ReadToolUseView(toolUse: ReadToolUseViewModel(status: .Just(.notStarted), input: .init(file_path: readPath, offset: nil, limit: nil)))
      ReadToolUseView(toolUse: ReadToolUseViewModel(
        status: .Just(.completed(.success(.init(
          content: """
            import Foundation

            func helloWorld() {
                print("Hello, world!")
            }

            // This is an example file content
            // for the ReadFileTool preview
            """)))),
        input: .init(file_path: readPath, offset: nil, limit: nil)))

      ReadToolUseView(toolUse: ReadToolUseViewModel(
        status: .Just(.completed(.success(.init(
          content: longContent)))),
        input: .init(file_path: readPath, offset: nil, limit: nil)))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
