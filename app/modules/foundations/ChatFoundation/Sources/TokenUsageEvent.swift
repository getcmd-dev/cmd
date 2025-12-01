// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LLMFoundation

// MARK: - TokenUsageEvent

/// Represents token usage information for a chat interaction.
/// This event is not displayed to the user but helps with deserialization and tracking context window usage.
public struct TokenUsageEvent: Sendable, Identifiable {
  public init(
    id: UUID = UUID(),
    inputTokens: Int,
    cachedInputTokens: Int,
    outputTokens: Int,
    timestamp: Date = Date())
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

  public var totalTokens: Int {
    inputTokens + outputTokens + cachedInputTokens
  }

  public func usageRatio(for model: AIModel) -> Double {
    Double(totalTokens) / Double(model.contextSize)
  }
}
