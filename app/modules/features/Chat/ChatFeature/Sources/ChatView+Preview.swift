// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import SwiftUI

#if DEBUG
#Preview {
  ChatView(viewModel: ChatViewModel(
    tab:
    ChatThreadViewModel(messages: [
      ChatMessageViewModel(
        content: [.text(.init(
          projectRoot: URL(filePath: "/"),
          text: "What does this code do?",
          attachments: [
            .fileSelection(AttachmentModel.FileSelectionAttachment(
              file: AttachmentModel.FileAttachment(
                path: URL(filePath: "/Users/me/app/source.swift")!,
                content: mediumFileContent),
              startLine: 4,
              endLine: 10)),
          ]))],
        role: .user),
    ]))).frame(minHeight: 400)
}
#endif
