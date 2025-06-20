// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodePreview
import DLS
import ServerServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ExecuteCommandTool.Use + DisplayableToolUse

extension ExecuteCommandTool.Use: DisplayableToolUse {
  public var body: AnyView {
    AnyView(ToolUseView(toolUse: ToolUseViewModel(
      command: input.command,
      status: status,
      stdout: stdoutStream,
      stderr: stderrStream,
      kill: killRunningProcess)))
  }
}

// MARK: - ToolUseView

struct ToolUseView: View {

  @Bindable var toolUse: ToolUseViewModel

  var body: some View {
    switch toolUse.status {
    case .notStarted:
      VStack { }
    case .pendingApproval:
      content(statusDescription: "Waiting for approval: \(toolUse.command)")
    case .approvalRejected:
      content(statusDescription: "Rejected: \(toolUse.command)")
    case .running:
      content(statusDescription: toolUse.command)
    case .completed(.success):
      content(statusDescription: toolUse.command)
    case .completed(.failure):
      content(statusDescription: "Running \(toolUse.command) failed")
    }
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

  @ViewBuilder
  private var stdoutView: some View {
    if let std = toolUse.std, !std.isEmpty {
      CodePreview(filePath: nil, content: std)
        .with(cornerRadius: 5, borderColor: colorScheme.textAreaBorderColor)
    }
  }

  @ViewBuilder
  private func content(statusDescription: String) -> some View {
    VStack(alignment: .leading) {
      HStack(alignment: .top, spacing: 0) {
        if isExpanded {
          Icon(systemName: "chevron.down")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        } else if isHovered {
          Icon(systemName: "chevron.right")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        } else {
          Icon(systemName: "apple.terminal")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        }
        Text(statusDescription)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
          .foregroundColor(foregroundColor)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.leading, 5)
        if case .running = toolUse.status {
          Spacer(minLength: 0)
          IconButton(
            action: {
              await toolUse.kill()
            },
            systemName: "stop.circle",
            padding: 2,
            cornerRadius: 0,
            withCheckMark: false)
            .frame(width: 15, height: 15)
        }
      }
      .tappableTransparentBackground()
      .onTapGesture { isExpanded.toggle() }
      if isExpanded {
        VStack(alignment: .leading, spacing: 8) {
          stdoutView
        }
        .frame(maxWidth: 600, alignment: .leading)
      }
    }.onHover { isHovered = $0 }
  }

}
