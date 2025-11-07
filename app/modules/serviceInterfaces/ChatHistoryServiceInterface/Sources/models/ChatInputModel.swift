// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Represents the serializable state of chat input.
public struct ChatInputModel: Sendable {
  public init(queuedMessages: [QueuedMessageModel]) {
    self.queuedMessages = queuedMessages
  }

  /// Messages that have been queued while the assistant is streaming a response.
  public let queuedMessages: [QueuedMessageModel]
}
