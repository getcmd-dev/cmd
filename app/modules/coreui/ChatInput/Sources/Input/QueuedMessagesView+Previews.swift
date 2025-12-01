// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatHistoryServiceInterface
import SwiftUI

#if DEBUG
#Preview {
  QueuedMessagesView(
    queuedMessages: .constant([
      QueuedMessageModel(
        id: UUID(),
        text: "and add a mermaid diagram",
        attachments: [],
        createdAt: Date()),
      QueuedMessageModel(
        id: UUID(),
        text: "Fix the authentication bug in the login flow",
        attachments: [],
        createdAt: Date()),
    ]),
    isExpanded: .constant(true),
    onSendNow: { _ in },
    onDelete: { _ in })
    .padding()
}
#endif
