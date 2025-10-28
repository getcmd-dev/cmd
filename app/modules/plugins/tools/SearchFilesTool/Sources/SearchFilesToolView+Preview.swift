// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import SwiftUI
import ToolTypesFoundation

#if DEBUG
let url = URL(filePath: "/path/to/some-file.txt")

typealias SearchFilesStatus = SearchFilesTool.Use.Status

#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      let input1 = SearchFilesTool.Input(
        directoryPath: "/path/to/dir",
        regex: "ENV_KEY*",
        filePattern: nil)
      ToolUseView(toolUse: ToolUseViewModel(
        status: SearchFilesStatus.Just(.running(input: input1)),
        input: input1,
        rootPath: "/path/to/"))

      let input2 = SearchFilesTool.Input(
        directoryPath: "/path/to/dir",
        regex: "ENV_KEY*",
        filePattern: nil)
      ToolUseView(toolUse: ToolUseViewModel(
        status: SearchFilesStatus.Just(.notStarted(input: input2)),
        input: input2,
        rootPath: "/path/to/"))

      let input3 = SearchFilesTool.Input(
        directoryPath: "/path/to/dir",
        regex: "ENV_KEY*",
        filePattern: nil)
      ToolUseView(toolUse: ToolUseViewModel(
        status: SearchFilesStatus.Just(.completed(input: input3, result: .success(SearchFilesTool.Use.Output(
          outputForLLm: "...",
          results: [
            ToolsSchema.SearchFileResult(
              path: "/path/to/dir/file.swift",
              searchResults: [
                .init(line: 3, text: "ENV_KEY_FOO", isMatch: true),
              ]),
          ],
          hasMore: false)))),
        input: input3,
        rootPath: "/path/to/"))
    }
  }
  .frame(minWidth: 200, minHeight: 500)
  .padding()
}
#endif
