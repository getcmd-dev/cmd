// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import JSONFoundation
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ToolUseView

struct ToolUseView: View {

  @Bindable var toolUse: ToolUseViewModel

  var body: some View {
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
          .foregroundColor(colorScheme.redError)
      }

      // Expanded section
      if isExpanded {
        VStack(alignment: .leading) {
          Text("Input")
          HStack {
            Text(toolUse.input.prettyPrintedString)
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
              .padding(4)
            Spacer(minLength: 0)
          }
          .with(cornerRadius: Constants.cornerRadius, backgroundColor: colorScheme.primaryBackground)

          switch toolUse.status {
          case .notStarted, .pendingApproval, .running, .approvalRejected:
            EmptyView()

          case .completed(.success(let output)):
            Text("Output")
            HStack {
              Text(output.prettyPrintedString)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(4)
              Spacer(minLength: 0)
            }
            .with(cornerRadius: Constants.cornerRadius, backgroundColor: colorScheme.primaryBackground)

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

// MARK: - JSONDisplayView

struct JSONDisplayView: View {
  let value: JSON.Value

  var body: some View {
    ScrollView(.horizontal) {
      Text(value.prettyPrintedString)
        .font(.system(.body, design: .monospaced))
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color(NSColor.textBackgroundColor))
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.gray.opacity(0.2), lineWidth: 1))
  }
}

extension JSON.Value {
  var prettyPrintedString: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if
      let data = try? encoder.encode(self),
      let jsonString = String(data: data, encoding: .utf8)
    {
      return jsonString
    } else {
      return "<invalid json data>"
    }
  }
}
