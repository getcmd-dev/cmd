// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodePreview
import DLS
import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation

#if DEBUG
// MARK: - Preview Provider

struct FileChangeView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      // Preview collapsed state
      FileChangeView(change: mockFileDiffViewModel, editState: .applied)
        .frame(width: 500)
        .preferredColorScheme(.dark)
        .previewDisplayName("Collapsed State")

      // Preview expanded state (pre-expanded)
      FileChangeView(change: mockFileDiffViewModel, editState: .rejected, initiallyExpanded: true)
        .frame(width: 500, height: 600)
        .preferredColorScheme(.dark)
        .previewDisplayName("Expanded State")

      // Error state
      FileChangeView(change: mockFileDiffViewModel, editState: .error("Could not apply file change."))
        .frame(width: 500)
        .preferredColorScheme(.dark)
        .previewDisplayName("Error State")
    }
    .padding()
    .background(Color.black)
  }

  /// Mock data for previews
  static var mockFileDiffViewModel: FileDiffViewModel {
    let filePath = URL(string: "file:///Users/user/Project/WindowInfo.swift")!
    let baseContent = """
      import Foundation

      struct WindowInfo {
          let id: String
          let title: String

          func describe() -> String {
              return "Window \\(id): \\(title)"
          }
      }
      """

    let targetContent = """
      import Foundation
      import AppKit

      struct WindowInfo: Identifiable {
          let id: String
          let title: String
          var isActive: Bool = false

          func describe() -> String {
              let status = isActive ? "active" : "inactive"
              return "Window \\(id): \\(title) (\\(status))"
          }
      }
      """

    return FileDiffViewModel(
      filePath: filePath,
      baseLineContent: baseContent,
      targetContent: targetContent,
      canBeApplied: true,
      formattedDiff: nil, // Setting to nil to test the fallback in our extension
    )
  }
}
#endif
