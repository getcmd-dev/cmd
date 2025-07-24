// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodePreview
import DLS
import ServerServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeReadTool.Use + DisplayableToolUse

extension ClaudeCodeReadTool.Use: DisplayableToolUse {
  public var body: AnyView {
    AnyView(ToolUseView(toolUse: ToolUseViewModel(
      status: status, input: input)))
  }
}

// MARK: - ToolUseView

struct ToolUseView: View {

  @Bindable var toolUse: ToolUseViewModel

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

          Text("Read(\(toolUse.filePath.lastPathComponent))")
            .foregroundColor(foregroundColor)
        }

        if let output {
          HStack {
            Rectangle()
              .fill(Color.clear)
              .frame(width: 8, height: 8)

            Text(" ⎿  Read \(lineCount(output.content)) lines")
              .foregroundColor(foregroundColor)
          }

          if isExpanded {
            CodePreview(
              filePath: toolUse.filePath,
              language: FileIcon.language(for: toolUse.filePath),
              content: output.content,
              highlightedContent: toolUse.highlightedContent,
              collapsedHeight: 400)
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

  private var output: ClaudeCodeReadTool.Use.Output? {
    switch toolUse.status {
    case .completed(.success(let output)):
      output
    default:
      nil
    }
  }

  private func lineCount(_ content: String) -> Int {
    content.components(separatedBy: .newlines).count
  }

}

extension ToolUseViewModel {
  var filePath: URL { URL(fileURLWithPath: input.file_path) }
}
