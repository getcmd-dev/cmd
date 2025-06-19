// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFeatureInterface
import ConcurrencyFoundation
import Foundation
import SwiftTesting
import Testing
@testable import ChatHistoryServiceInterface

// MARK: - MockChatHistoryServiceTests

struct MockChatHistoryServiceTests {

  // MARK: - Save Tests

  @Test("Save new thread - default behavior")
  func test_saveNewThread_defaultBehavior() async throws {
    let sut = MockChatHistoryService()
    let thread = createTestThread(name: "New Thread")

    try await sut.save(chatThread: thread)

    // Verify thread was added to internal storage
    let metadata = try await sut.loadLastChatThreads(last: 10, offset: 0)
    #expect(metadata.count == 1)
    #expect(metadata.first?.id == thread.id)
    #expect(metadata.first?.name == "New Thread")
  }

  @Test("Save existing thread - default behavior updates")
  func test_saveExistingThread_defaultBehavior() async throws {
    let threadId = UUID()
    let originalThread = createTestThread(id: threadId, name: "Original")
    let sut = MockChatHistoryService(chatThreads: [originalThread])

    let updatedThread = createTestThread(id: threadId, name: "Updated")
    try await sut.save(chatThread: updatedThread)

    // Verify thread was updated
    let loadedThread = try await sut.loadChatThread(id: threadId)
    #expect(loadedThread?.name == "Updated")

    // Verify only one thread exists
    let metadata = try await sut.loadLastChatThreads(last: 10, offset: 0)
    #expect(metadata.count == 1)
  }

  @Test("Save thread - custom callback behavior")
  func test_saveThread_customCallback() async throws {
    let sut = MockChatHistoryService()
    let thread = createTestThread()
    let callbackThread = Atomic<ChatThreadModel?>(nil)

    sut.onSaveChatThread = { savedThread in
      callbackThread.set(to: savedThread)
    }

    try await sut.save(chatThread: thread)

    #expect(callbackThread.value?.id == thread.id)
    #expect(callbackThread.value?.name == thread.name)
  }

  @Test("Save thread - callback throws error")
  func test_saveThread_callbackThrowsError() async throws {
    let sut = MockChatHistoryService()
    let thread = createTestThread()
    let expectedError = AppError("Save failed")

    sut.onSaveChatThread = { _ in
      throw expectedError
    }

    do {
      try await sut.save(chatThread: thread)
      Issue.record("Expected error to be thrown")
    } catch let error as AppError {
      #expect(error.localizedDescription == expectedError.localizedDescription)
    }
  }

  // MARK: - Load Threads Tests

  @Test("Load last threads - default behavior with sorting")
  func test_loadLastThreads_defaultBehavior() async throws {
    let now = Date()
    let thread1 = createTestThread(name: "Thread 1", createdAt: now.addingTimeInterval(-100))
    let thread2 = createTestThread(name: "Thread 2", createdAt: now.addingTimeInterval(-50))
    let thread3 = createTestThread(name: "Thread 3", createdAt: now)

    let sut = MockChatHistoryService(chatThreads: [thread1, thread2, thread3])

    let metadata = try await sut.loadLastChatThreads(last: 10, offset: 0)

    #expect(metadata.count == 3)
    // Should be sorted newest first
    #expect(metadata[0].name == "Thread 3")
    #expect(metadata[1].name == "Thread 2")
    #expect(metadata[2].name == "Thread 1")
  }

  @Test("Load last threads - pagination")
  func test_loadLastThreads_pagination() async throws {
    let threads = (0..<5).map { i in
      createTestThread(name: "Thread \(i)", createdAt: Date().addingTimeInterval(TimeInterval(-i)))
    }
    let sut = MockChatHistoryService(chatThreads: threads)

    // Load first 2 threads
    let firstPage = try await sut.loadLastChatThreads(last: 2, offset: 0)
    #expect(firstPage.count == 2)
    #expect(firstPage[0].name == "Thread 0")
    #expect(firstPage[1].name == "Thread 1")

    // Load next 2 threads
    let secondPage = try await sut.loadLastChatThreads(last: 2, offset: 2)
    #expect(secondPage.count == 2)
    #expect(secondPage[0].name == "Thread 2")
    #expect(secondPage[1].name == "Thread 3")

    // Load remaining thread
    let thirdPage = try await sut.loadLastChatThreads(last: 2, offset: 4)
    #expect(thirdPage.count == 1)
    #expect(thirdPage[0].name == "Thread 4")
  }

  @Test("Load last threads - custom callback returns result")
  func test_loadLastThreads_customCallback() async throws {
    let threads = Array(0..<11).map { i in
      createTestThread(id: UUID(), name: "Custom Thread #\(i)", createdAt: Date(timeIntervalSinceNow: TimeInterval(-i)))
    }
    let sut = MockChatHistoryService(chatThreads: threads)
    let receivedLast = Atomic<Int?>(nil)
    let receivedOffset = Atomic<Int?>(nil)

    sut.onLoadLastChatThreads = { last, offset in
      receivedLast.set(to: last)
      receivedOffset.set(to: offset)
    }

    let result = try await sut.loadLastChatThreads(last: 5, offset: 10)

    #expect(receivedLast.value == 5)
    #expect(receivedOffset.value == 10)
    #expect(result.count == 1)
    #expect(result.first?.name == "Custom Thread #10")
  }

  @Test("Load last threads - callback fallback to default")
  func test_loadLastThreads_callbackFallbackToDefault() async throws {
    let thread = createTestThread(name: "Default Thread")
    let sut = MockChatHistoryService(chatThreads: [thread])

    let result = try await sut.loadLastChatThreads(last: 10, offset: 0)

    #expect(result.count == 1)
    #expect(result.first?.name == "Default Thread")
  }

  // MARK: - Load Single Thread Tests

  @Test("Load thread by ID - default behavior success")
  func test_loadThread_defaultBehaviorSuccess() async throws {
    let threadId = UUID()
    let thread = createTestThread(id: threadId, name: "Found Thread")
    let sut = MockChatHistoryService(chatThreads: [thread])

    let result = try await sut.loadChatThread(id: threadId)

    #expect(result?.id == threadId)
    #expect(result?.name == "Found Thread")
  }

  @Test("Load thread by ID - default behavior not found")
  func test_loadThread_defaultBehaviorNotFound() async throws {
    let sut = MockChatHistoryService()
    let nonExistentId = UUID()

    let result = try await sut.loadChatThread(id: nonExistentId)

    #expect(result == nil)
  }

  @Test("Load thread by ID - custom callback")
  func test_loadThread_customCallback() async throws {
    let threadId = UUID()
    let expectedThread = createTestThread(id: threadId, name: "Custom Thread")
    let sut = MockChatHistoryService(chatThreads: [expectedThread])
    let receivedId = Atomic<UUID?>(nil)

    sut.onLoadChatThread = { id in
      receivedId.set(to: id)
    }

    let result = try await sut.loadChatThread(id: threadId)

    #expect(receivedId.value == threadId)
    #expect(result?.id == threadId)
    #expect(result?.name == "Custom Thread")
  }

  @Test("Load thread by ID - callback fallback to default")
  func test_loadThread_callbackFallbackToDefault() async throws {
    let threadId = UUID()
    let thread = createTestThread(id: threadId, name: "Default Thread")
    let sut = MockChatHistoryService(chatThreads: [thread])

    // Return nil from callback to use default behavior
    sut.onLoadChatThread = { _ in
      nil
    }

    let result = try await sut.loadChatThread(id: threadId)

    #expect(result?.name == "Default Thread")
  }

  // MARK: - Delete Thread Tests

  @Test("Delete thread - default behavior removes thread")
  func test_deleteThread_defaultBehavior() async throws {
    let threadId = UUID()
    let thread = createTestThread(id: threadId, name: "To Delete")
    let otherThread = createTestThread(name: "Keep This")
    let sut = MockChatHistoryService(chatThreads: [thread, otherThread])

    try await sut.deleteChatThread(id: threadId)

    // Verify thread was deleted
    let result = try await sut.loadChatThread(id: threadId)
    #expect(result == nil)

    // Verify other thread remains
    let metadata = try await sut.loadLastChatThreads(last: 10, offset: 0)
    #expect(metadata.count == 1)
    #expect(metadata.first?.name == "Keep This")
  }

  @Test("Delete thread - delete non-existent thread")
  func test_deleteThread_nonExistentThread() async throws {
    let sut = MockChatHistoryService()
    let nonExistentId = UUID()

    // Should not throw error when deleting non-existent thread
    try await sut.deleteChatThread(id: nonExistentId)

    let metadata = try await sut.loadLastChatThreads(last: 10, offset: 0)
    #expect(metadata.isEmpty)
  }

  @Test("Delete thread - custom callback")
  func test_deleteThread_customCallback() async throws {
    let sut = MockChatHistoryService()
    let threadId = UUID()
    let receivedId = Atomic<UUID?>(nil)

    sut.onDeleteChatThread = { id in
      receivedId.set(to: id)
    }

    try await sut.deleteChatThread(id: threadId)

    #expect(receivedId.value == threadId)
  }

  @Test("Delete thread - callback throws error")
  func test_deleteThread_callbackThrowsError() async throws {
    let sut = MockChatHistoryService()
    let threadId = UUID()
    let expectedError = AppError("Delete failed")

    sut.onDeleteChatThread = { _ in
      throw expectedError
    }

    do {
      try await sut.deleteChatThread(id: threadId)
      Issue.record("Expected error to be thrown")
    } catch let error as AppError {
      #expect(error.localizedDescription == expectedError.localizedDescription)
    }
  }

  // MARK: - Integration Tests

  @Test("Full workflow - save, load, update, delete")
  func test_fullWorkflow() async throws {
    let sut = MockChatHistoryService()
    let threadId = UUID()

    // Save new thread
    let originalThread = createTestThread(id: threadId, name: "Original")
    try await sut.save(chatThread: originalThread)

    // Load and verify
    var loadedThread = try await sut.loadChatThread(id: threadId)
    #expect(loadedThread?.name == "Original")

    // Update thread
    let updatedThread = createTestThread(id: threadId, name: "Updated")
    try await sut.save(chatThread: updatedThread)

    // Load and verify update
    loadedThread = try await sut.loadChatThread(id: threadId)
    #expect(loadedThread?.name == "Updated")

    // Verify in thread list
    var metadata = try await sut.loadLastChatThreads(last: 10, offset: 0)
    #expect(metadata.count == 1)
    #expect(metadata.first?.name == "Updated")

    // Delete thread
    try await sut.deleteChatThread(id: threadId)

    // Verify deletion
    loadedThread = try await sut.loadChatThread(id: threadId)
    #expect(loadedThread == nil)

    metadata = try await sut.loadLastChatThreads(last: 10, offset: 0)
    #expect(metadata.isEmpty)
  }

  @Test("Multiple threads management")
  func test_multipleThreadsManagement() async throws {
    let sut = MockChatHistoryService()

    // Create and save multiple threads
    let threads = (1...5).map { i in
      createTestThread(name: "Thread \(i)", createdAt: Date().addingTimeInterval(TimeInterval(-i)))
    }

    for thread in threads {
      try await sut.save(chatThread: thread)
    }

    // Verify all threads exist
    let metadata = try await sut.loadLastChatThreads(last: 10, offset: 0)
    #expect(metadata.count == 5)

    // Verify ordering (newest first)
    #expect(metadata[0].name == "Thread 1")
    #expect(metadata[4].name == "Thread 5")

    // Delete middle thread
    try await sut.deleteChatThread(id: threads[2].id)

    // Verify deletion
    let updatedMetadata = try await sut.loadLastChatThreads(last: 10, offset: 0)
    #expect(updatedMetadata.count == 4)
    #expect(!updatedMetadata.contains { $0.name == "Thread 3" })
  }

  // MARK: - Test Data

  private func createTestThread(
    id: UUID = UUID(),
    name: String = "Test Thread",
    createdAt: Date = Date())
    -> ChatThreadModel
  {
    ChatThreadModel(
      id: id,
      name: name,
      messages: [],
      events: [],
      projectInfo: nil,
      createdAt: createdAt)
  }

}
