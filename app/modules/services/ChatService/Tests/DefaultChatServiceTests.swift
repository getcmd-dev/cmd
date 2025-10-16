// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatServiceInterface
import Foundation
import SwiftTesting
import Testing
@testable import ChatService

// MARK: - TestViewModel

private final class TestViewModel: Sendable {
  init(id: String) {
    self.id = id
  }

  let id: String
}

// MARK: - DefaultChatServiceTests

struct DefaultChatServiceTests {

  // MARK: - Keep Alive Tests

  @Test
  func testKeepAlive() {
    let service = DefaultChatService()
    let viewModel = TestViewModel(id: "vm1")
    let threadId = UUID()

    service.keepAlive(viewModel, for: threadId)

    let retrieved: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved?.id == "vm1")
  }

  @Test
  func testStopKeepingAlive() {
    let service = DefaultChatService()
    let viewModel = TestViewModel(id: "vm1")
    let threadId = UUID()

    service.keepAlive(viewModel, for: threadId)
    let retrieved1: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved1 != nil)

    service.stopKeepingAlive(viewModel, for: threadId)

    // Since we stopped keeping alive and it's not buffered, it should be gone
    // The viewModel local reference keeps it alive during the test
    let retrieved: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved == nil)
  }

  // MARK: - Buffer Tests

  @Test
  func testBuffer() {
    let service = DefaultChatService()
    let viewModel = TestViewModel(id: "vm1")
    let threadId = UUID()

    service.buffer(viewModel, for: threadId)

    let retrieved: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved?.id == "vm1")
  }

  @Test
  func testBufferWeakReference() {
    let service = DefaultChatService()
    let threadId = UUID()

    do {
      let viewModel = TestViewModel(id: "vm1")
      service.buffer(viewModel, for: threadId)

      // Should still be accessible while in scope
      let retrieved: TestViewModel? = service.knownObject(for: threadId)
      #expect(retrieved?.id == "vm1")
    }

    // After viewModel goes out of scope, it should be deallocated
    let retrieved: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved == nil)
  }

  @Test
  func testBufferLRUEviction() {
    let service = DefaultChatService()
    var viewModels = [TestViewModel]()
    var threadIds = [UUID]()

    // Create 11 view models (capacity is 10)
    for i in 0..<11 {
      let vm = TestViewModel(id: "vm\(i)")
      let threadId = UUID()
      viewModels.append(vm)
      threadIds.append(threadId)
      service.buffer(vm, for: threadId)
    }

    // The first one should be evicted (LRU)
    let firstVM: TestViewModel? = service.knownObject(for: threadIds[0])
    #expect(firstVM == nil)

    // All others should still be accessible
    for i in 1..<11 {
      let vm: TestViewModel? = service.knownObject(for: threadIds[i])
      #expect(vm?.id == "vm\(i)")
    }
  }

  @Test
  func testBufferLRUAccessOrder() {
    let service = DefaultChatService()
    var viewModels = [TestViewModel]()
    var threadIds = [UUID]()

    // Create 10 view models (filling capacity)
    for i in 0..<10 {
      let vm = TestViewModel(id: "vm\(i)")
      let threadId = UUID()
      viewModels.append(vm)
      threadIds.append(threadId)
      service.buffer(vm, for: threadId)
    }

    // Access the first one, making it most recently used
    let _: TestViewModel? = service.knownObject(for: threadIds[0])

    // Add one more, which should evict thread-1 (now the LRU)
    let vm10 = TestViewModel(id: "vm10")
    let threadId10 = UUID()
    viewModels.append(vm10)
    threadIds.append(threadId10)
    service.buffer(vm10, for: threadId10)

    // thread-0 should still be accessible (we accessed it recently)
    let firstVM: TestViewModel? = service.knownObject(for: threadIds[0])
    #expect(firstVM?.id == "vm0")

    // thread-1 should be evicted
    let secondVM: TestViewModel? = service.knownObject(for: threadIds[1])
    #expect(secondVM == nil)
  }

  @Test
  func testBufferUpdateExisting() {
    let service = DefaultChatService()
    let viewModel1 = TestViewModel(id: "vm1")
    let viewModel2 = TestViewModel(id: "vm2")
    let threadId = UUID()

    service.buffer(viewModel1, for: threadId)

    let retrieved1: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved1?.id == "vm1")

    // Update with a different view model
    service.buffer(viewModel2, for: threadId)

    let retrieved2: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved2?.id == "vm2")
  }

  // MARK: - Known Object Tests

  @Test
  func testKnownObjectPrioritizesStrongReference() {
    let service = DefaultChatService()
    let strongVM = TestViewModel(id: "strong")
    let weakVM = TestViewModel(id: "weak")
    let threadId = UUID()

    // First buffer a weak reference
    service.buffer(weakVM, for: threadId)

    // Then add a strong reference for the same thread
    service.keepAlive(strongVM, for: threadId)

    // Should return the strong reference
    let retrieved: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved?.id == "strong")
  }

  @Test
  func testKnownObjectReturnsNilForUnknownThread() {
    let service = DefaultChatService()

    let retrieved: TestViewModel? = service.knownObject(for: UUID())
    #expect(retrieved == nil)
  }

  // MARK: - Integration Tests

  @Test
  func testCompleteLifecycle() {
    let service = DefaultChatService()
    let viewModel = TestViewModel(id: "vm1")
    let threadId = UUID()

    // Start with keep alive
    service.keepAlive(viewModel, for: threadId)
    let retrieved1: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved1 != nil)

    // Stop keeping alive
    service.stopKeepingAlive(viewModel, for: threadId)
    let retrieved2: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved2 == nil)

    // Buffer it
    service.buffer(viewModel, for: threadId)
    let retrieved3: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved3 != nil)
  }

  @Test
  func testMultipleThreads() {
    let service = DefaultChatService()
    let vm1 = TestViewModel(id: "vm1")
    let vm2 = TestViewModel(id: "vm2")
    let vm3 = TestViewModel(id: "vm3")
    let threadId1 = UUID()
    let threadId2 = UUID()
    let threadId3 = UUID()

    service.keepAlive(vm1, for: threadId1)
    service.keepAlive(vm2, for: threadId2)
    service.buffer(vm3, for: threadId3)

    let retrieved1: TestViewModel? = service.knownObject(for: threadId1)
    let retrieved2: TestViewModel? = service.knownObject(for: threadId2)
    let retrieved3: TestViewModel? = service.knownObject(for: threadId3)

    #expect(retrieved1?.id == "vm1")
    #expect(retrieved2?.id == "vm2")
    #expect(retrieved3?.id == "vm3")
  }

  @Test
  func testBufferCapacityExactly10() {
    let service = DefaultChatService()
    var viewModels = [TestViewModel]()
    var threadIds = [UUID]()

    // Add exactly 10 items
    for i in 0..<10 {
      let vm = TestViewModel(id: "vm\(i)")
      let threadId = UUID()
      viewModels.append(vm)
      threadIds.append(threadId)
      service.buffer(vm, for: threadId)
    }

    // All 10 should be accessible
    for i in 0..<10 {
      let vm: TestViewModel? = service.knownObject(for: threadIds[i])
      #expect(vm?.id == "vm\(i)")
    }

    // Add one more
    let vm10 = TestViewModel(id: "vm10")
    let threadId10 = UUID()
    viewModels.append(vm10)
    threadIds.append(threadId10)
    service.buffer(vm10, for: threadId10)

    // Now only 10 should be accessible (thread-0 should be evicted)
    let evicted: TestViewModel? = service.knownObject(for: threadIds[0])
    #expect(evicted == nil)

    // All others should be accessible
    for i in 1..<11 {
      let vm: TestViewModel? = service.knownObject(for: threadIds[i])
      #expect(vm?.id == "vm\(i)")
    }
  }

  // MARK: - Streaming Retention Use Case Tests

  @Test("View model is retained during streaming lifecycle")
  func testStreamingRetentionLifecycle() {
    let service = DefaultChatService()
    let viewModel = TestViewModel(id: "streaming-vm")
    let threadId = UUID()

    weak var weakRef = viewModel

    // Simulate streaming start - keepAlive
    service.keepAlive(viewModel, for: threadId)

    // Should be strongly retained even in this scope
    #expect(weakRef != nil)
    let retrieved1: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved1?.id == "streaming-vm")

    // Simulate streaming end - stop keeping alive and buffer
    service.stopKeepingAlive(viewModel, for: threadId)
    service.buffer(viewModel, for: threadId)

    // Should still be accessible from buffer while viewModel is in scope
    let retrieved2: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved2?.id == "streaming-vm")
  }

  @Test("Strong reference prevents deallocation when weak ref would fail")
  func testStrongReferencePreventsDeal() {
    let service = DefaultChatService()
    let threadId = UUID()

    weak var weakRef: TestViewModel?

    do {
      let viewModel = TestViewModel(id: "protected-vm")
      weakRef = viewModel

      // Start keeping alive
      service.keepAlive(viewModel, for: threadId)
    }
    // viewModel goes out of scope here, but should still be retained

    // Should still be accessible because service has strong reference
    let retrieved: TestViewModel? = service.knownObject(for: threadId)
    #expect(retrieved?.id == "protected-vm")
    #expect(weakRef != nil, "Weak reference should still be valid due to strong retention")
  }

  @Test("Buffered instance is reused when requested again")
  func testBufferedInstanceReuse() {
    let service = DefaultChatService()
    let viewModel = TestViewModel(id: "reusable-vm")
    let threadId = UUID()

    // Buffer the view model
    service.buffer(viewModel, for: threadId)

    // Retrieve it multiple times - should be the same instance
    let retrieved1: TestViewModel? = service.knownObject(for: threadId)
    let retrieved2: TestViewModel? = service.knownObject(for: threadId)

    #expect(retrieved1 != nil)
    #expect(retrieved2 != nil)
    #expect(retrieved1 === retrieved2, "Should return the exact same instance")
  }

  @Test("Transition from strong to weak reference works correctly")
  func testTransitionFromStrongToWeakReference() {
    let service = DefaultChatService()
    let viewModel = TestViewModel(id: "transition-vm")
    let threadId = UUID()

    // Start with strong reference (streaming)
    service.keepAlive(viewModel, for: threadId)
    let strongRetrieved: TestViewModel? = service.knownObject(for: threadId)
    #expect(strongRetrieved?.id == "transition-vm")

    // Transition to weak reference (buffer after streaming completes)
    service.stopKeepingAlive(viewModel, for: threadId)
    service.buffer(viewModel, for: threadId)

    // Should still be accessible from buffer
    let weakRetrieved: TestViewModel? = service.knownObject(for: threadId)
    #expect(weakRetrieved?.id == "transition-vm")
    #expect(strongRetrieved === weakRetrieved, "Should be the same instance")
  }
}
