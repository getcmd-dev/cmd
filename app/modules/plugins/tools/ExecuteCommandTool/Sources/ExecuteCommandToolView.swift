// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodePreview
import DLS
import ServerServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ToolUseView

/// A SwiftUI view that displays the status and output of a tool execution.
///
/// This view presents a command execution with its current status, allowing users to:
/// - See the command being executed
/// - View its current status (not started, pending approval, rejected, running, or completed)
/// - Expand/collapse to see stdout/stderr output
/// - Stop a running command
///
/// The view adapts its appearance based on hover state and execution status,
/// using different colors to indicate success or failure states.
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
    case .running, .completed:
      content(statusDescription: toolUse.command)
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
    if let std {
      CodePreview(filePath: nil, content: std)
        .with(cornerRadius: 5, borderColor: colorScheme.textAreaBorderColor)
    }
  }

  private var statusColor: Color {
    switch toolUse.status {
    case .completed(.failure):
      colorScheme.removedLineDiffText
    case .completed(.success):
      colorScheme.addedLineDiffText
    default: .gray
    }
  }

  private var errorDescription: String? {
    switch toolUse.status {
    case .completed(.failure(let error)):
      error.localizedDescription
    default:
      nil
    }
  }

  private var std: String? {
    if toolUse.std?.isEmpty == false || errorDescription?.isEmpty == false {
      return "\(toolUse.std ?? "")\(errorDescription ?? "")"
    }
    return nil
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

        Spacer(minLength: 0)

        if case .running = toolUse.status {
          IconButton(
            action: {
              await toolUse.kill()
            },
            systemName: "stop.circle",
            padding: 2,
            cornerRadius: 0,
            withCheckMark: false)
            .frame(width: 15, height: 15)
        } else {
          Circle()
            .frame(width: 6, height: 6)
            .foregroundColor(statusColor)
            .frame(height: 14)
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
