// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeLSTool.Use + DisplayableToolUse

extension ClaudeCodeLSTool.Use: DisplayableToolUse {
  public var body: AnyView {
    AnyView(LSToolUseView(toolUse: LSToolUseViewModel(
      status: status, input: input)))
  }
}

// MARK: - LSToolUseView

struct LSToolUseView: View {

  @Bindable var toolUse: LSToolUseViewModel

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

          Text("LS(\(toolUse.directoryPath.lastPathComponent))")
            .foregroundColor(foregroundColor)
        }

        if let output {
          HStack {
            Rectangle()
              .fill(Color.clear)
              .frame(width: 8, height: 8)

            Text(" ⎿  Listed directory contents")
              .foregroundColor(foregroundColor)
          }

          if isExpanded {
            HStack {
              Rectangle()
                .fill(Color.clear)
                .frame(width: 8, height: 8)
              
              VStack(alignment: .leading, spacing: 2) {
                Text(output.content)
                  .font(.system(size: 12).monospaced())
                  .foregroundColor(foregroundColor)
                  .textSelection(.enabled)
                  .padding(8)
                  .background(Color(NSColor.controlBackgroundColor))
                  .cornerRadius(4)
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

  private var output: ClaudeCodeLSTool.Use.Output? {
    switch toolUse.status {
    case .completed(.success(let output)):
      output
    default:
      nil
    }
  }
}

extension LSToolUseViewModel {
  var directoryPath: URL { URL(fileURLWithPath: input.path) }
}