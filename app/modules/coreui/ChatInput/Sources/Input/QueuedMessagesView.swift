// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatHistoryServiceInterface
import DLS
import SwiftUI

// MARK: - QueuedMessagesView

struct QueuedMessagesView: View {

  init(
    queuedMessages: Binding<[QueuedMessageModel]>,
    isExpanded: Binding<Bool>,
    onSendNow: @escaping (QueuedMessageModel) -> Void,
    onDelete: @escaping (UUID) -> Void)
  {
    _queuedMessages = queuedMessages
    _isExpanded = isExpanded
    self.onSendNow = onSendNow
    self.onDelete = onDelete
  }

  var body: some View {
    if !queuedMessages.isEmpty {
      VStack(spacing: 0) {
        // Header - entire row is tappable for expand/collapse
        HStack(spacing: 4) {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
          Text("\(queuedMessages.count) Queued")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
          Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(colorScheme.secondarySystemBackground)
        .contentShape(Rectangle())
        .onTapGesture {
          isExpanded.toggle()
        }

        // Queue items
        if isExpanded {
          ForEach(queuedMessages) { message in
            QueuedMessageRow(
              message: message,
              onSendNow: { onSendNow(message) },
              onDelete: { onDelete(message.id) })
          }
        }
      }
      .cornerRadius(6)
      .with(cornerRadius: 6, borderColor: colorScheme.textAreaBorderColor)
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  @Binding private var queuedMessages: [QueuedMessageModel]
  @Binding private var isExpanded: Bool

  private let onSendNow: (QueuedMessageModel) -> Void
  private let onDelete: (UUID) -> Void
}

// MARK: - QueuedMessageRow

struct QueuedMessageRow: View {

  let message: QueuedMessageModel
  let onSendNow: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      // Status indicator
      Circle()
        .fill(Color.secondary.opacity(0.3))
        .frame(width: 8, height: 8)

      // Message preview
      Text(messagePreview)
        .font(.system(size: 13))
        .foregroundColor(.primary)
        .lineLimit(1)
        .truncationMode(.tail)

      Spacer()

      // Actions (visible on hover)
      if isHovered {
        HStack(spacing: 4) {
          // Send now
          Button {
            onSendNow()
          } label: {
            HStack(spacing: 2) {
              Image(systemName: "arrow.turn.up.right")
                .font(.system(size: 10))
              Text("to send now")
                .font(.system(size: 11))
            }
            .foregroundColor(.blue)
          }
          .buttonStyle(.plain)

          // Delete
          Button {
            onDelete()
          } label: {
            Image(systemName: "trash")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovered = false

  private var messagePreview: String {
    let preview = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if preview.count > 60 {
      return String(preview.prefix(60)) + "..."
    }
    return preview
  }
}
