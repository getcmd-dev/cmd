// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ThreadSafe

@ThreadSafe
final class LRUQueue<Item: Sendable>: Sendable, Sequence {

  init(_ capacity: Int = 100) {
    self.capacity = capacity
  }

  typealias Element = (Int, Item)

  func makeIterator() -> [(Int, Item)].Iterator {
    inLock { state in
      var elements = [(Int, Item)]()
      var h = state.head
      while h != nil {
        elements.append((h!.key, h!.value))
        h = h?.next
      }
      return elements.makeIterator()
    }
  }

  func use(_ key: Int) {
    inLock { state in
      if let node = state.dict[key] {
        moveToHead(node, &state)
      }
    }
  }

  @discardableResult
  func insert(_ value: Item) -> Int {
    inLock { state in
      let key = state.nextKey
      state.nextKey += 1
      add(Node(key, value), &state)
      if state.dict.count > capacity {
        removeTail(&state)
      }
      return key
    }
  }

  @discardableResult
  func remove(_ key: Int) -> Item? {
    inLock { state in
      if let node = state.dict[key] {
        remove(node, &state)
        return state.dict.removeValue(forKey: key)?.value
      }
      return nil
    }
  }

  private class Node: @unchecked Sendable {
    init(_ key: Int, _ value: Item) {
      self.key = key
      self.value = value
    }

    let key: Int
    var value: Item
    var prev: Node?
    var next: Node?
  }

  private let capacity: Int
  private var dict = [Int: Node]()
  private var nextKey = 0
  private var head: Node? = nil
  private var tail: Node? = nil

  private func add(_ node: Node, _ state: inout _InternalState) {
    defer { state.dict[node.key] = node }
    guard let head = state.head else {
      // empty list
      state.head = node
      state.tail = node
      return
    }
    node.next = head
    head.prev = node
    state.head = node
  }

  private func remove(_ node: Node, _ state: inout _InternalState) {
    if let prev = node.prev {
      prev.next = node.next
    } else {
      state.head = node.next
    }
    if let next = node.next {
      next.prev = node.prev
    } else {
      state.tail = node.prev
    }
    node.prev = nil
    node.next = nil
  }

  private func moveToHead(_ node: Node, _ state: inout _InternalState) {
    remove(node, &state)
    add(node, &state)
  }

  private func removeTail(_ state: inout _InternalState) {
    if let node = state.tail {
      remove(node, &state)
      state.dict.removeValue(forKey: node.key)
    }
  }
}
