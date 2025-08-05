// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import ChatServiceInterface
import Dependencies
import SwiftUI

#if DEBUG

let date = Date()

extension ChatThreadModel {
  init(
    id: UUID = UUID(),
    name: String,
    messages: [ChatMessageModel] = [],
    events: [ChatEventModel] = [],
    projectInfo: SelectedProjectInfo? = nil,
    createdAt: Date)
  {
    self.init(
      id: id,
      name: name,
      messages: messages,
      events: events,
      projectInfo: projectInfo,
      knownFilesContent: [:],
      createdAt: createdAt)
  }
}

#Preview {
  withDependencies {
    $0.chatHistoryService = MockChatHistoryService(
      chatThreads: [
        .init(
          name: "last thread",
          createdAt: Date(timeInterval: -1, since: date)),
        .init(
          name: "other thread",
          createdAt: Date(timeInterval: -2, since: date)),
      ]
        + Array(repeating: 0, count: 100).indices.map { i in
          .init(
            name: "other thread # \(i)",
            createdAt: Date(timeInterval: TimeInterval(-2 - i * 3600 * 3), since: date))
        })
  } operation: {
    ChatHistoryView(
      viewModel: ChatHistoryViewModel(),
      onBack: { },
      onSelectThread: { _ in })
      .frame(width: 400, height: 600)
  }
}
#endif
