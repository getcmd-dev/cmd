// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import ChatServiceInterface
import ConcurrencyFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
@testable import ChatFeature

@MainActor
struct ChatHistoryViewModelTests {

  @Test
  func testLoadInitialThreads() async throws {
    let mockThreads = [
      ChatThreadModel(
        id: UUID(),
        name: "Test Thread 1",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: Date().addingTimeInterval(-3600)),
      ChatThreadModel(
        id: UUID(),
        name: "Test Thread 2",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: Date()),
    ]

    let viewModel = withDependencies {
      $0.chatHistoryService = MockChatHistoryService(chatThreads: mockThreads)
    } operation: {
      ChatHistoryViewModel()
    }

    await viewModel.loadMoreThreadsIfNeeded()

    #expect(viewModel.threads.count == 2)
    #expect(viewModel.threads[0].name == "Test Thread 2") // Most recent first
    #expect(viewModel.threads[1].name == "Test Thread 1")
    #expect(!viewModel.isLoading)
  }

  @Test
  func testPagination() async throws {
    let mockThreads = Array(0..<25).map { index in
      ChatThreadModel(
        id: UUID(),
        name: "Thread \(index)",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: Date().addingTimeInterval(TimeInterval(-index * 3600)))
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = MockChatHistoryService(chatThreads: mockThreads)
    } operation: {
      ChatHistoryViewModel()
    }

    await viewModel.loadMoreThreadsIfNeeded()

    #expect(viewModel.threads.count == 20) // First page
    #expect(viewModel.hasMoreThreads)

    await viewModel.loadMoreThreadsIfNeeded()

    #expect(viewModel.threads.count == 25) // All threads loaded
    #expect(!viewModel.hasMoreThreads)
  }

  @Test
  func testReload() async throws {
    let mockThreads = [
      ChatThreadModel(
        id: UUID(),
        name: "Thread 1",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: Date()),
    ]
    let fetchCount = Atomic(0)
    let chatHistoryService = MockChatHistoryService(chatThreads: mockThreads)
    chatHistoryService.onLoadLastChatThreads = { _, _ in
      fetchCount.increment()
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = chatHistoryService
    } operation: {
      ChatHistoryViewModel()
    }

    // Load initial threads
    await viewModel.loadMoreThreadsIfNeeded()
    #expect(viewModel.threads.count == 1)

    // Reload should reset and load again
    await viewModel.reload()
    #expect(viewModel.threads.count == 1)
    #expect(!viewModel.isLoading)
    #expect(viewModel.hasMoreThreads == false) // Only 1 thread, so no more
  }

  @Test
  func testLoadingState() async throws {
    let mockService = MockChatHistoryService()
    let startedToLoadExp = expectation(description: "started to load")
    let didLoadExp = expectation(description: "loading state validated")

    mockService.onLoadLastChatThreads = { _, _ in
      startedToLoadExp.fulfill()
      // Adds delay until loading state has been validated.
      try await fulfillment(of: didLoadExp)
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = mockService
    } operation: {
      ChatHistoryViewModel()
    }

    #expect(!viewModel.isLoading)

    let loadTask = Task {
      await viewModel.loadMoreThreadsIfNeeded()
    }

    try await fulfillment(of: startedToLoadExp)
    #expect(viewModel.isLoading == true)
    didLoadExp.fulfill()

    await loadTask.value
    #expect(viewModel.isLoading == false)
  }

  @Test
  func testPreventConcurrentLoading() async throws {
    let mockService = MockChatHistoryService()
    let callCount = Atomic(0)
    let exp = expectation(description: "bothRequestsSent")

    mockService.onLoadLastChatThreads = { _, _ in
      callCount.increment()
      try await fulfillment(of: exp)
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = mockService
    } operation: {
      ChatHistoryViewModel()
    }

    // Start two concurrent loads
    async let load1: Void = viewModel.loadMoreThreadsIfNeeded()
    async let load2: Void = viewModel.loadMoreThreadsIfNeeded()
    exp.fulfill()

    await load1
    await load2

    #expect(callCount.value == 1) // Should only call service once
  }

  @Test
  func testThreadsByDayGrouping() async throws {
    let now = Date()
    let yesterday = now.addingTimeInterval(-86400) // 1 day ago
    let twoDaysAgo = now.addingTimeInterval(-172800) // 2 days ago

    let mockThreads = [
      ChatThreadModel(
        id: UUID(),
        name: "Today Thread",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: now),
      ChatThreadModel(
        id: UUID(),
        name: "Yesterday Thread",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: yesterday),
      ChatThreadModel(
        id: UUID(),
        name: "Two Days Ago Thread",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: twoDaysAgo),
    ]

    let viewModel = withDependencies {
      $0.chatHistoryService = MockChatHistoryService(chatThreads: mockThreads)
    } operation: {
      ChatHistoryViewModel()
    }

    await viewModel.loadMoreThreadsIfNeeded()

    #expect(viewModel.threadsByDay.count == 3) // 3 different days
    #expect(viewModel.threadsByDay[0].key == 0) // Today (0 days ago)
    #expect(viewModel.threadsByDay[1].key == 1) // Yesterday (1 day ago)
    #expect(viewModel.threadsByDay[2].key == 2) // Two days ago (2 days ago)
  }

  @Test
  func testEmptyState() async throws {
    let viewModel = withDependencies {
      $0.chatHistoryService = MockChatHistoryService(chatThreads: [])
    } operation: {
      ChatHistoryViewModel()
    }

    await viewModel.loadMoreThreadsIfNeeded()

    #expect(viewModel.threads.isEmpty)
    #expect(viewModel.threadsByDay.isEmpty)
    #expect(!viewModel.hasMoreThreads)
    #expect(!viewModel.isLoading)
  }

  @Test
  func testErrorHandling() async throws {
    let mockService = MockChatHistoryService()

    mockService.onLoadLastChatThreads = { _, _ in
      throw NSError(domain: "TestError", code: 1, userInfo: nil)
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = mockService
    } operation: {
      ChatHistoryViewModel()
    }

    await viewModel.loadMoreThreadsIfNeeded()

    #expect(viewModel.threads.isEmpty)
    #expect(!viewModel.isLoading)
    #expect(viewModel.hasMoreThreads) // Should remain true on error
  }

  @Test
  func testHasMoreThreadsLogic() async throws {
    // Test with exactly pageSize threads (20)
    let exactPageThreads = Array(0..<20).map { index in
      ChatThreadModel(
        id: UUID(),
        name: "Thread \(index)",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: Date().addingTimeInterval(TimeInterval(-index * 3600)))
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = MockChatHistoryService(chatThreads: exactPageThreads)
    } operation: {
      ChatHistoryViewModel()
    }

    await viewModel.loadMoreThreadsIfNeeded()

    #expect(viewModel.threads.count == 20)
    #expect(viewModel.hasMoreThreads) // Should be true when count equals pageSize

    // Second load should return empty and set hasMoreThreads to false
    await viewModel.loadMoreThreadsIfNeeded()
    #expect(!viewModel.hasMoreThreads)
  }

  @Test
  func testReloadResetsState() async throws {
    let mockThreads = Array(0..<25).map { index in
      ChatThreadModel(
        id: UUID(),
        name: "Thread \(index)",
        messages: [],
        events: [],
        projectInfo: nil,
        createdAt: Date().addingTimeInterval(TimeInterval(-index * 3600)))
    }

    let viewModel = withDependencies {
      $0.chatHistoryService = MockChatHistoryService(chatThreads: mockThreads)
    } operation: {
      ChatHistoryViewModel()
    }

    // Load first page
    await viewModel.loadMoreThreadsIfNeeded()
    #expect(viewModel.threads.count == 20)
    #expect(viewModel.hasMoreThreads)

    // Reload should reset everything
    await viewModel.reload()
    #expect(viewModel.threads.count == 20) // First page again
    #expect(viewModel.hasMoreThreads)
  }
}
