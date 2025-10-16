// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatServiceInterface
import DependencyFoundation
import Foundation
import ThreadSafe

// MARK: - DefaultChatService

@ThreadSafe
final class DefaultChatService: ChatService {

  init() { }

  func keepAlive(_ viewModel: some AnyObject & Sendable, for threadId: UUID) {
    inLock { state in
      // Ensure we don't keep alive twice for the same thread
      if state.strongReferences[threadId] != nil {
        assertionFailure("keepAlive called twice for threadId: \(threadId)")
      }
      state.strongReferences[threadId] = viewModel
    }
  }

  func stopKeepingAlive(_: some AnyObject, for threadId: UUID) {
    inLock { state in
      state.strongReferences.removeValue(forKey: threadId)
    }
  }

  func buffer(_ viewModel: some AnyObject & Sendable, for threadId: UUID) {
    inLock { state in
      state.lruBuffer.set(viewModel, for: threadId)
    }
  }

  func knownObject<ViewModel: AnyObject>(for threadId: UUID) -> ViewModel? {
    inLock { state in
      // First check strong references
      if let strongRef = state.strongReferences[threadId] as? ViewModel {
        return strongRef
      }

      // Then check buffered references and update LRU access
      if let bufferedRef = state.lruBuffer.get(for: threadId) as? ViewModel {
        return bufferedRef
      }

      return nil
    }
  }

  private var strongReferences = [UUID: any Sendable]()
  private var lruBuffer = LRUBuffer(capacity: 10)
}

// MARK: - LRUBuffer

/// A Least Recently Used (LRU) cache that holds weak references to view models.
/// When the cache is full and a new item is added, the least recently accessed item is evicted.
private final class LRUBuffer: @unchecked Sendable {

  init(capacity: Int) {
    self.capacity = capacity
  }

  func set(_ value: AnyObject, for key: UUID) {
    // Remove existing node if present
    if let existingNode = cache[key] {
      removeNode(existingNode)
    }

    // Create new node and add to front
    let node = Node(key: key, value: value)
    addToFront(node)
    cache[key] = node

    // Evict LRU if over capacity
    if cache.count > capacity {
      if let lru = tail {
        removeNode(lru)
        cache.removeValue(forKey: lru.key)
      }
    }
  }

  func get(for key: UUID) -> AnyObject? {
    guard let node = cache[key] else {
      return nil
    }

    // Check if the weak reference is still valid
    guard let value = node.value else {
      // Clean up dead reference
      removeNode(node)
      cache.removeValue(forKey: key)
      return nil
    }

    // Move to front (most recently used)
    removeNode(node)
    addToFront(node)

    return value
  }

  private final class Node: @unchecked Sendable {
    init(key: UUID, value: AnyObject) {
      self.key = key
      self.value = value
    }

    let key: UUID
    weak var value: AnyObject?
    var prev: Node?
    var next: Node?

  }

  private let capacity: Int
  private var cache = [UUID: Node]()
  private var head: Node?
  private var tail: Node?

  private func addToFront(_ node: Node) {
    node.next = head
    node.prev = nil

    if let head {
      head.prev = node
    }

    head = node

    if tail == nil {
      tail = node
    }
  }

  private func removeNode(_ node: Node) {
    let prev = node.prev
    let next = node.next

    if let prev {
      prev.next = next
    } else {
      head = next
    }

    if let next {
      next.prev = prev
    } else {
      tail = prev
    }

    node.prev = nil
    node.next = nil
  }
}

// MARK: - Dependency Injection

extension BaseProviding {
  public var chatService: ChatService {
    shared {
      DefaultChatService()
    }
  }
}
