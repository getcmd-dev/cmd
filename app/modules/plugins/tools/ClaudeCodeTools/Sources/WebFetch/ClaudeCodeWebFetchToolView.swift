// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeWebFetchTool.Use + DisplayableToolUse

extension ClaudeCodeWebFetchTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    AnyToolUseViewModel(WebFetchToolUseViewModel(status: status, input: input))
  }
}

// MARK: - WebFetchToolUseView

struct WebFetchToolUseView: View {

  @Bindable var toolUse: WebFetchToolUseViewModel

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

          HStack(spacing: 0) {
            Text("Fetch(")
              .foregroundColor(foregroundColor)
            LinkView(url: toolUse.input.url)
              .foregroundColor(foregroundColor)
            Text(")")
              .foregroundColor(foregroundColor)
          }
        }

        if let output {
          if isExpanded {
            HStack {
              Rectangle()
                .fill(Color.clear)
                .frame(width: 8, height: 8)

              ScrollView {
                Text(output.result)
                  .font(.caption)
                  .foregroundColor(colorScheme.toolUseForeground)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .textSelection(.enabled)
              }
              .frame(maxHeight: 200)
            }
          } else {
            HStack {
              Rectangle()
                .fill(Color.clear)
                .frame(width: 8, height: 8)

              Text(output.result)
                .font(.caption)
                .foregroundColor(colorScheme.toolUseForeground)
                .lineLimit(1)
                .truncationMode(.tail)
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

  private var output: ClaudeCodeWebFetchTool.Use.Output? {
    switch toolUse.status {
    case .completed(.success(let output)):
      output
    default:
      nil
    }
  }
}

// MARK: - LinkView

struct LinkView: View {
  let url: String

  var body: some View {
    if let url = URL(string: url) {
      PlainLink(url.absoluteString, destination: url)
    } else {
      Text(url)
    }
  }

}
