// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

import CheckpointServiceInterface

// MARK: - ChatEvent

public enum ChatEventModel: Sendable {
  case message(_ message: ChatMessageContentWithRoleModel)
  case checkpoint(_ checkpoint: Checkpoint)
}
