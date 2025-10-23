// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

import CheckpointServiceInterface

// MARK: - ChatEventModel

public enum ChatEventModel: Sendable {
  case message(_ message: ChatMessageContentWithRoleModel)
  case checkpoint(_ checkpoint: Checkpoint)
  case tokenUsage(_ tokenUsage: TokenUsageEventModel)
}

// MARK: - TokenUsageEventModel

/// Represents token usage information for persistence
public struct TokenUsageEventModel: Sendable, Codable {
  public init(
    id: UUID,
    inputTokens: Int,
    cachedInputTokens: Int,
    outputTokens: Int,
    timestamp: Date)
  {
    self.id = id
    self.inputTokens = inputTokens
    self.cachedInputTokens = cachedInputTokens
    self.outputTokens = outputTokens
    self.timestamp = timestamp
  }

  public let id: UUID
  public let inputTokens: Int
  public let cachedInputTokens: Int
  public let outputTokens: Int
  public let timestamp: Date

}
