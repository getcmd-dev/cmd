// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import FileDiffTypesFoundation
import SwiftUI

#Preview("Code Completion with Two-Line Diff") {
  let mockCompletion = CompletionSuggestion(
    file: URL(fileURLWithPath: "/path/to/file.swift"),
    newContent: """
      func calculateTotal(
        items: [Double]
      ) -> Double {
        return items.reduce(0, +)
      }
      """,
    newCursorSelection: Range(
      start: .init(line: 0, character: 0),
      end: .init(line: 0, character: 0)),
    diffLineStart: 1,
    diff: [
      CompletionSuggestion.LineChange(
        changes: [
          .init(text: "func ", type: .unchanged),
          .init(text: "calculateSum", type: .removed),
          .init(text: "calculateTotal", type: .added),
          .init(text: "(", type: .unchanged),
        ]),
      CompletionSuggestion.LineChange(
        changes: [
          .init(text: "  items: [", type: .unchanged),
          .init(text: "Int", type: .removed),
          .init(text: "Double", type: .added),
          .init(text: "]", type: .unchanged),
        ]),
    ])

  CompletionDiffView(completion: mockCompletion)
}
