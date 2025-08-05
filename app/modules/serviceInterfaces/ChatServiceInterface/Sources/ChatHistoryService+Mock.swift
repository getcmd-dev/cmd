// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockChatHistoryService: ChatHistoryService {

  public init(chatThreads: [ChatThreadModel] = []) {
    self.chatThreads = chatThreads
    setupDefaultMocks()
  }

  public var onSaveChatThread: (@Sendable (ChatThreadModel) async throws -> Void)?

  public var onLoadLastChatThreads: (@Sendable (Int, Int) async throws -> Void)?

  public var onLoadChatThread: (@Sendable (UUID) async throws -> Void?)?

  public var onDeleteChatThread: (@Sendable (UUID) async throws -> Void)?

  public func save(chatThread: ChatThreadModel) async throws {
    try await onSaveChatThread?(chatThread)

    return try await _saveChatThread(chatThread)
  }

  public func loadLastChatThreads(last: Int, offset: Int) async throws -> [ChatThreadModelMetadata] {
    try await onLoadLastChatThreads?(last, offset)

    return try await _loadLastChatThreads(last, offset)
  }

  public func loadChatThread(id: UUID) async throws -> ChatThreadModel? {
    try await onLoadChatThread?(id)
    return try await _loadChatThread(id)
  }

  public func deleteChatThread(id: UUID) async throws {
    try await onDeleteChatThread?(id)

    return try await _deleteChatThread(id)
  }

  private var _saveChatThread: @Sendable (ChatThreadModel) async throws -> Void = { _ in }

  private var _loadLastChatThreads: @Sendable (Int, Int) async throws -> [ChatThreadModelMetadata] = { _, _ in [] }

  private var _loadChatThread: @Sendable (UUID) async throws -> ChatThreadModel? = { _ in nil }

  private var _deleteChatThread: @Sendable (UUID) async throws -> Void = { _ in }

  private var chatThreads: [ChatThreadModel]

  private func setupDefaultMocks() {
    _saveChatThread = { [weak self] chatThread in
      guard let self else { return }

      if let index = chatThreads.firstIndex(where: { $0.id == chatThread.id }) {
        chatThreads[index] = chatThread
      } else {
        chatThreads.append(chatThread)
      }
    }

    _loadLastChatThreads = { [weak self] last, offset in
      guard let self else { return [] }
      let sortedThreads = chatThreads.sorted { $0.createdAt > $1.createdAt }
      let slicedThreads = Array(sortedThreads.dropFirst(offset).prefix(last))

      return slicedThreads.map { thread in
        ChatThreadModelMetadata(
          id: thread.id,
          name: thread.name,
          createdAt: thread.createdAt)
      }
    }

    _loadChatThread = { [weak self] id in
      guard let self else { return nil }
      return chatThreads.first { $0.id == id }
    }

    _deleteChatThread = { [weak self] id in
      guard let self else { return }

      chatThreads.removeAll { $0.id == id }
    }
  }

}
#endif
