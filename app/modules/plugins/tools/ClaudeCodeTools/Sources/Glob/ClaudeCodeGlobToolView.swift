// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeGlobTool.Use + DisplayableToolUse

extension ClaudeCodeGlobTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(GlobToolUseViewModel(status: status, input: input))
  }
}

// MARK: - GlobToolUseView

struct GlobToolUseView: View {

  @Bindable var toolUse: GlobToolUseViewModel

  var body: some View {
    HoveredButton(action: {
      isExpanded.toggle()
    }) {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Circle()
            .fill(output != nil ? Color.green : Color.gray)
            .frame(width: 8, height: 8)
            .frame(alignment: .top)

          Text("Glob(\(toolUse.input.pattern))")
            .foregroundColor(foregroundColor)
        }

        if let output {
          HStack {
            Rectangle()
              .fill(Color.clear)
              .frame(width: 8, height: 8)

            Text(" ⎿ Found \(output.files.count) files")
              .foregroundColor(foregroundColor)
          }

          if isExpanded {
            VStack(alignment: .leading, spacing: 2) {
              ForEach(output.files.prefix(20), id: \.self) { filePath in
                HStack(spacing: 4) {
                  Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)

                  FileIcon(filePath: URL(fileURLWithPath: filePath))
                    .frame(width: 14, height: 14)

                  Text(URL(fileURLWithPath: filePath).lastPathComponent)
                    .font(.caption)
                    .foregroundColor(foregroundColor)
                    .lineLimit(1)

                  Text(shortenPath(filePath))
                    .font(.caption2)
                    .foregroundColor(colorScheme.toolUseForeground)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .layoutPriority(-1)

                  Spacer(minLength: 0)
                }
              }

              if output.files.count > 20 {
                HStack {
                  Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)

                  Text("... and \(output.files.count - 20) more files")
                    .font(.caption2)
                    .foregroundColor(colorScheme.toolUseForeground)
                    .italic()
                }
              }
            }
          }
        }
      }
    }
    .onHover { isHovered = $0 }
  }

  @State private var isExpanded = false
  @State private var isHovered = false

  @Environment(\.colorScheme) private var colorScheme

  private var foregroundColor: Color {
    if isHovered {
      .primary
    } else {
      colorScheme.toolUseForeground
    }
  }

  private var output: ClaudeCodeGlobTool.Use.Output? {
    switch toolUse.status {
    case .completed(.success(let output)):
      output
    default:
      nil
    }
  }

  private func shortenPath(_ fullPath: String) -> String {
    let url = URL(fileURLWithPath: fullPath)
    let directory = url.deletingLastPathComponent().path

    // Remove common prefixes or just show relative path
    if directory.hasPrefix("/Users") {
      let components = directory.components(separatedBy: "/")
      if components.count > 4 {
        return ".../" + components.suffix(2).joined(separator: "/")
      }
    }

    return directory
  }
}
