// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeWebSearchTool.Use + DisplayableToolUse

extension ClaudeCodeWebSearchTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(WebSearchToolUseViewModel(status: status, input: input))
  }
}

// MARK: - WebSearchToolUseView

struct WebSearchToolUseView: View {

  @Bindable var toolUse: WebSearchToolUseViewModel

  var body: some View {
    HoveredButton(action: {
      isExpanded.toggle()
    }) {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .frame(alignment: .top)

          Text("WebSearch: \(toolUse.input.query)")
            .foregroundColor(foregroundColor)
            .lineLimit(1)
            .truncationMode(.tail)
        }

        if let output {
          if isExpanded {
            VStack(alignment: .leading, spacing: 8) {
              // Show search results
              if !output.links.isEmpty {
                HStack {
                  Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)

                  VStack(alignment: .leading, spacing: 4) {
                    Text("Results:")
                      .font(.caption)
                      .foregroundColor(colorScheme.toolUseForeground)

                    ForEach(Array(output.links.enumerated()), id: \.offset) { index, link in
                      HStack(alignment: .top, spacing: 4) {
                        Text("\(index + 1).")
                          .font(.caption)
                          .foregroundColor(colorScheme.toolUseForeground)
                        VStack(alignment: .leading, spacing: 2) {
                          Text(link.title)
                            .font(.caption)
                            .foregroundColor(colorScheme.toolUseForeground)
                            .lineLimit(1)
                          LinkView(url: link.url)
                            .font(.caption)
                            .foregroundColor(colorScheme.toolUseForeground)
                        }
                      }
                    }
                  }
                }
              }

              // Show content summary
              if !output.content.isEmpty {
                HStack {
                  Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)

                  ScrollView {
                    Text(output.content)
                      .font(.caption)
                      .foregroundColor(colorScheme.toolUseForeground)
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .textSelection(.enabled)
                  }
                  .frame(maxHeight: 200)
                }
              }
            }
          } else {
            HStack {
              Rectangle()
                .fill(Color.clear)
                .frame(width: 8, height: 8)

              Text("Found \(output.links.count) results")
                .font(.caption)
                .foregroundColor(colorScheme.toolUseForeground)
            }
          }
        } else if isRunning {
          HStack {
            Rectangle()
              .fill(Color.clear)
              .frame(width: 8, height: 8)

            HStack(spacing: 0) {
              Text("Searching")
                .font(.caption)
                .foregroundColor(colorScheme.toolUseForeground)
              ThreeDotsLoadingAnimation()
            }
          }
        } else if let error = errorDescription {
          HStack {
            Rectangle()
              .fill(Color.clear)
              .frame(width: 8, height: 8)

            HStack(spacing: 4) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(colorScheme.removedLineDiffText)
              Text("Error: \(error)")
                .font(.caption)
                .textSelection(.enabled)
                .foregroundColor(colorScheme.toolUseForeground)
                .lineLimit(isExpanded ? nil : 1)
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

  private var output: ClaudeCodeWebSearchTool.Use.Output? {
    switch toolUse.status {
    case .completed(.success(let output)):
      output
    default:
      nil
    }
  }

  private var isRunning: Bool {
    if case .running = toolUse.status {
      return true
    }
    return false
  }

  private var statusColor: Color {
    switch toolUse.status {
    case .completed(.failure):
      colorScheme.removedLineDiffText
    case .completed(.success):
      colorScheme.addedLineDiffText
    case .running:
      Color.orange
    case .notStarted:
      Color.gray
    case .pendingApproval:
      Color.yellow
    case .approvalRejected:
      colorScheme.removedLineDiffText
    }
  }

  private var errorDescription: String? {
    switch toolUse.status {
    case .completed(.failure(let error)):
      error.localizedDescription
    case .approvalRejected(let reason):
      reason ?? "Tool use was rejected"
    default:
      nil
    }
  }
}
