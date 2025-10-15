// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import Foundation

// MARK: - ChatHistoryService

public protocol ChatHistoryService: Sendable {
  func loadLastChatThreads(last: Int, offset: Int) async throws -> [ChatThreadModelMetadata]
  func loadChatThread(id: UUID) async throws -> ChatThreadModel?
  func save(chatThread: ChatThreadModel) async throws
  func deleteChatThread(id: UUID) async throws
}

// MARK: - ChatThreadModelMetadata

public struct ChatThreadModelMetadata: Sendable, Identifiable {
  public let id: UUID
  public let name: String
  public let createdAt: Date

  public init(id: UUID, name: String, createdAt: Date) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
  }
}
