// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import ConcurrencyFoundation
import SwiftUI

#if DEBUG
extension ChatMessageList {
  init(messages: [ChatMessageViewModel]) {
    self.init(events: messages.flatMap { message in
      message.content.map { .message(ChatMessageContentWithRole(content: $0, role: message.role)) }
    })
  }
}

/// A helper view to simulate streaming of chat messages.
struct DebugStreamingMessages: View {

  init(messages: [ChatMessageViewModel]) {
    self.messages = messages
  }

  var body: some View {
    VStack {
      HStack {
        Button("Stream one chunk") {
          _ = streamOneChunk()
        }
        Button("Stream all chunks") {
          Task {
            while streamOneChunk() {
              try await Task.sleep(nanoseconds: 50_000_000)
            }
          }
        }
        Button("Reset") {
          currentMessages.value = []
        }
      }.padding()
      ChatMessageList(messages: currentMessages.value)
    }
  }

  @Bindable private var currentMessages = ObservableValue<[ChatMessageViewModel]>([])

  private let messages: [ChatMessageViewModel]

  private func streamOneChunk() -> Bool {
    var currentMessages = currentMessages.value
    if let (i, currentMessage) = Array(currentMessages.enumerated()).last {
      if currentMessage.streamOneChunk(from: messages[i]) {
        return true
      }
    }
    // try to add new message
    let i = currentMessages.count
    if messages.count > i {
      currentMessages.append(ChatMessageViewModel(content: [], role: messages[i].role))
      self.currentMessages.value = currentMessages
      // Add some content to the new message.
      return streamOneChunk()
    }
    // Done streaming
    return false
  }
}

#Preview {
  ChatMessageList(messages: [
    ChatMessageViewModel(
      content: [.text(.init(text: "What does this code do?", attachments: [
        .fileSelection(AttachmentModel.FileSelectionAttachment(
          file: AttachmentModel.FileAttachment(
            path: URL(filePath: "/Users/me/app/source.swift")!,
            content: mediumFileContent),
          startLine: 4,
          endLine: 10)),
      ]))],
      role: .user),
    ChatMessageViewModel(
      content: [.text(.init(text: "Not much"))],
      role: .assistant),
    ChatMessageViewModel(
      content: [.text(.init(text: messageContentWithCode))],
      role: .assistant),
  ])
  .frame(maxWidth: 400, maxHeight: .infinity)
}

#Preview {
  DebugStreamingMessages(messages: [
    ChatMessageViewModel(
      content: [.text(.init(text: "What does this code do?", attachments: [
        .fileSelection(AttachmentModel.FileSelectionAttachment(
          file: AttachmentModel.FileAttachment(
            path: URL(filePath: "/Users/me/app/source.swift")!,
            content: mediumFileContent),
          startLine: 4,
          endLine: 10)),
      ]))],
      role: .user),
    ChatMessageViewModel(
      content: [.text(.init(text: "Not much"))],
      role: .assistant),
    ChatMessageViewModel(
      content: [.text(.init(text: messageContentWithCode))],
      role: .assistant),
  ])
  .frame(maxWidth: 400, maxHeight: .infinity)
}

#endif
