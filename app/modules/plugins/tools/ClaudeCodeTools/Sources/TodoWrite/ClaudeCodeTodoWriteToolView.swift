// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeTodoWriteTool.Use + DisplayableToolUse

extension ClaudeCodeTodoWriteTool.Use: DisplayableToolUse {
  public var body: AnyView {
    AnyView(TodoWriteToolUseView(toolUse: TodoWriteToolUseViewModel(
      status: status, input: input)))
  }
}

// MARK: - TodoWriteToolUseView

struct TodoWriteToolUseView: View {

  @Bindable var toolUse: TodoWriteToolUseViewModel

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

          Text("TodoWrite")
            .foregroundColor(foregroundColor)
        }

        if let output {
          HStack {
            Rectangle()
              .fill(Color.clear)
              .frame(width: 8, height: 8)

            Text(" ⎿  \(output.message)")
              .foregroundColor(foregroundColor)
          }

          if isExpanded {
            VStack(alignment: .leading, spacing: 2) {

              ForEach(toolUse.input.todos.prefix(10), id: \.id) { todo in
                HStack(spacing: 4) {
                  Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)

                  statusIcon(for: todo.status)
                    .frame(width: 12, height: 12)

                  priorityIndicator(for: todo.priority)
                    .frame(width: 4, height: 12)

                  Text(todo.content)
                    .font(.caption)
                    .foregroundColor(foregroundColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                  Spacer(minLength: 0)
                }
                .padding(.vertical, 1)
              }

              if toolUse.input.todos.count > 10 {
                HStack {
                  Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)

                  Text("... and \(toolUse.input.todos.count - 10) more items")
                    .font(.caption2)
                    .foregroundColor(colorScheme.toolUseForeground)
                    .italic()
                }
              }
            }
            .padding(.top, 2)
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

  private var output: ClaudeCodeTodoWriteTool.Use.Output? {
    switch toolUse.status {
    case .completed(.success(let output)):
      output
    default:
      nil
    }
  }

  private func statusIcon(for status: String) -> some View {
    Group {
      switch status {
      case "completed":
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(.green)
      case "in_progress":
        Image(systemName: "play.circle.fill")
          .foregroundColor(.orange)
      case "pending":
        Image(systemName: "circle")
          .foregroundColor(.gray)
      default:
        Image(systemName: "circle")
          .foregroundColor(.gray)
      }
    }
  }

  private func priorityIndicator(for priority: String) -> some View {
    Rectangle()
      .fill(priorityColor(for: priority))
      .frame(width: 3)
  }

  private func priorityColor(for priority: String) -> Color {
    switch priority {
    case "high":
      return .red
    case "medium":
      return .orange
    case "low":
      return .blue
    default:
      return .gray
    }
  }
}
