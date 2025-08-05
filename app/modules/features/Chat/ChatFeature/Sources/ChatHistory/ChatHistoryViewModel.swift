// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatServiceInterface
import Dependencies
import Foundation
import LoggingServiceInterface
import Observation

@MainActor @Observable
final class ChatHistoryViewModel {

  init() {
    @Dependency(\.chatHistoryService) var chatHistoryService
    self.chatHistoryService = chatHistoryService
  }

  typealias ThreadInfo = ChatThreadModelMetadata

  private(set) var threadsByDay: [(key: Int, value: [ThreadInfo])] = []

  private(set) var isLoading = false
  private(set) var hasMoreThreads = true

  private(set) var threads: [ThreadInfo] = [] {
    didSet {
      let dict: [Int: [ChatHistoryViewModel.ThreadInfo]] = threads.reduce(into: [:]) { result, thread in
        let dayDiff = Int(Date().timeIntervalSince(thread.createdAt) / 86400)
        result[dayDiff, default: []].append(thread)
      }
      threadsByDay = Array(dict).sorted(by: { $0.key < $1.key })
    }
  }

  func reload() async {
    guard !isLoading else { return }
    currentOffset = 0
    threads = []
    hasMoreThreads = true
    await loadMoreThreadsIfNeeded()
  }

  func loadMoreThreadsIfNeeded() async {
    guard !isLoading, hasMoreThreads else { return }

    isLoading = true

    do {
      let newThreads = try await chatHistoryService.loadLastChatThreads(
        last: pageSize,
        offset: currentOffset)

      threads.append(contentsOf: newThreads)
      currentOffset += newThreads.count
      hasMoreThreads = newThreads.count == pageSize
    } catch {
      defaultLogger.error("Failed to load chat threads", error)
    }

    isLoading = false
  }

  private let pageSize = 20
  private var currentOffset = 0

  private let chatHistoryService: ChatHistoryService

}
