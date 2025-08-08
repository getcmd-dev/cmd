// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeTodoWriteTool.Use + DisplayableToolUse

extension ClaudeCodeTodoWriteTool.Use: DisplayableToolUse {
  public var body: AnyView {
    AnyView(TodoWriteToolUseView(toolUse: TodoWriteToolUseViewModel(
      status: status,
      input: input,
      preExistingTodos: internalState?.preExistingTodos)))
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

        VStack(alignment: .leading, spacing: 2) {
          // Show current todos
          ForEach(toolUse.input.todos.filter { !toolUse.todoChange(for: $0).isUnchanged || isExpanded }, id: \.id) { todo in
            let change = toolUse.todoChange(for: todo)
            HStack(spacing: 4) {
              Rectangle()
                .fill(Color.clear)
                .frame(width: 8, height: 8)

              statusIcon(for: todo.status, change: change)
                .frame(width: 12, height: 12)

              Text(todo.content)
                .font(.caption)
                .foregroundColor(foregroundColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

              Spacer(minLength: 0)
            }
            .padding(.vertical, 1)
          }

          // Show removed todos with strikethrough
          ForEach(toolUse.removedTodos, id: \.id) { todo in
            HStack(spacing: 4) {
              Rectangle()
                .fill(Color.clear)
                .frame(width: 8, height: 8)

              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .frame(width: 12, height: 12)

              Text(todo.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .strikethrough()
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

              Spacer(minLength: 0)
            }
            .padding(.vertical, 1)
          }
        }
        .padding(.top, 2)
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

  private func statusIcon(for status: String, change _: TodoWriteToolUseViewModel.TodoChange) -> some View {
    Group {
      switch status {
      case "completed":
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(.green)

      case "in_progress":
        Image(systemName: "play.circle.fill")
          .foregroundColor(.green)

      case "pending":
        Image(systemName: "circle")
          .foregroundColor(.gray)

      default:
        Image(systemName: "circle")
          .foregroundColor(.gray)
      }
    }
  }
}
