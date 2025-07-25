// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      GlobToolUseView(toolUse: GlobToolUseViewModel(
        status: .Just(.running),
        input: .init(pattern: "**/*.swift", path: nil)))

      GlobToolUseView(toolUse: GlobToolUseViewModel(
        status: .Just(.notStarted),
        input: .init(pattern: "src/**/*.ts", path: "/Users/user/project")))

      GlobToolUseView(toolUse: GlobToolUseViewModel(
        status: .Just(.completed(.success(.init(
          files: [
            "/Users/user/project/src/main.swift",
            "/Users/user/project/src/utils/helpers.swift",
            "/Users/user/project/src/models/User.swift",
            "/Users/user/project/src/views/ContentView.swift",
            "/Users/user/project/tests/MainTests.swift",
          ])))),
        input: .init(pattern: "**/*.swift", path: nil)))

      GlobToolUseView(toolUse: GlobToolUseViewModel(
        status: .Just(.completed(.success(.init(
          files: Array(0..<30).map { "/Users/user/project/file\($0).txt" })))),
        input: .init(pattern: "**/*.txt", path: nil)))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
