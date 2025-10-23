// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CheckpointServiceInterface

enum ChatEvent: Identifiable {
  case message(_ message: ChatMessageContentWithRole)
  case checkpoint(_ checkpoint: Checkpoint)
  case tokenUsage(_ tokenUsage: TokenUsageEvent)

  var message: ChatMessageContentWithRole? {
    if case .message(let message) = self {
      return message
    }
    return nil
  }

  var checkpoint: Checkpoint? {
    if case .checkpoint(let checkpoint) = self {
      return checkpoint
    }
    return nil
  }

  var tokenUsage: TokenUsageEvent? {
    if case .tokenUsage(let tokenUsage) = self {
      return tokenUsage
    }
    return nil
  }

  var id: String {
    switch self {
    case .message(let message):
      message.id.uuidString
    case .checkpoint(let checkpoint):
      checkpoint.id
    case .tokenUsage(let tokenUsage):
      tokenUsage.id.uuidString
    }
  }
}
