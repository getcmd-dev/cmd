// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import JSONFoundation
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - DefaultToolUseView

public struct DefaultToolUseView: View {

  public var body: some View {
    VStack(alignment: .leading) {
      // First row
      HStack {
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
          Icon(systemName: "hammer")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        }

        switch toolUse.status {
        case .notStarted:
          Text("\(toolUse.toolName)")
            .foregroundColor(foregroundColor)

        case .pendingApproval:
          Text("Waiting for approval: \(toolUse.toolName)")
            .foregroundColor(foregroundColor)

        case .approvalRejected:
          Text("Rejected: Search \(toolUse.toolName)")
            .foregroundColor(foregroundColor)

        case .running:
          Text("Running \(toolUse.toolName)...")
            .foregroundColor(foregroundColor)

        case .completed:
          Text("\(toolUse.toolName)")
            .foregroundColor(foregroundColor)
        }
      }
      .tappableTransparentBackground()
      .onTapGesture { isExpanded.toggle() }
      .acceptClickThrough()

      // Optional second row
      switch toolUse.status {
      case .notStarted, .pendingApproval, .approvalRejected, .running, .completed(.success):
        EmptyView()
      case .completed(.failure(let error)):
        Text(error.localizedDescription)
          .textSelection(.enabled)
          .foregroundColor(colorScheme.redError)
      }

      // Expanded section
      if isExpanded {
        VStack(alignment: .leading) {
          Text("Input")
          HStack {
            Text(toolUse.input ?? "<invalid JSON>")
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
              .padding(4)
            Spacer(minLength: 0)
          }
          .with(cornerRadius: Constants.cornerRadius, backgroundColor: colorScheme.secondarySystemBackground)

          switch toolUse.status {
          case .notStarted, .pendingApproval, .running, .approvalRejected:
            EmptyView()

          case .completed(.success(let output)):
            Text("Output")
            HStack {
              Text(output ?? "<invalid JSON>")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(4)
              Spacer(minLength: 0)
            }
            .with(cornerRadius: Constants.cornerRadius, backgroundColor: colorScheme.secondarySystemBackground)

          case .completed(.failure):
            EmptyView()
          }
        }

        .padding(10)
        .with(cornerRadius: Constants.cornerRadius, borderColor: colorScheme.textAreaBorderColor)
      }
    }
    .onHover { isHovered = $0 }
  }

  @Bindable var toolUse: DefaultToolUseViewModel

  private enum Constants {
    static let cornerRadius: CGFloat = 5
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
}
