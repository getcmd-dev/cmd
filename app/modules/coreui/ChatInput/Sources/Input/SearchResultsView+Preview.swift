// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileSuggestionServiceInterface
import SwiftUI

#Preview {
  VStack {
    SearchResultsView(
      selectedRowIndex: Binding.constant(0),
      results: [
        FileSuggestion(path: URL(filePath: "/path/to/app/file.swift"), displayPath: "app/file.swift", matchedRanges: []),
        FileSuggestion(
          path: URL(filePath: "/path/to/app/long-file-name.swift"),
          displayPath: "app/long-file-name.swift",
          matchedRanges: []),
        FileSuggestion(
          path: URL(filePath: "/path/to/app/very-very-long-file-name.swift"),
          displayPath: "app/very-very-long-file-name.swift",
          matchedRanges: []),
      ])
    Spacer()

    SearchResultsView(
      selectedRowIndex: Binding.constant(0),
      results: [
        FileSuggestion(path: URL(filePath: "/path/to/app/file.swift"), displayPath: "app/file.swift", matchedRanges: []),

      ],
      searchInput: .constant(""))
  }.frame(width: 200, height: 200)
    .padding(10)
}
