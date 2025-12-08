// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import CodeCompletionService

@Suite("LRUQueueTests")
struct LRUQueueTests {

  @Test("Insert, iterate, use first item, iterate again")
  func insertIterateUseFirstIterateAgain() async throws {
    // given
    let sut = LRUQueue<String>()
    sut.insert("first")
    sut.insert("second")
    sut.insert("third")

    // when - iterate over items
    var firstIteration = [(Int, String)]()
    for item in sut {
      firstIteration.append(item)
    }

    // then - verify initial order (most recently inserted first)
    #expect(firstIteration.count == 3)
    #expect(firstIteration[0].1 == "third")
    #expect(firstIteration[1].1 == "second")
    #expect(firstIteration[2].1 == "first")

    // when - pick the first one and use it
    let firstKey = try #require(firstIteration.first?.0)
    sut.use(firstKey)

    // when - iterate over the list again
    var secondIteration = [(Int, String)]()
    for item in sut {
      secondIteration.append(item)
    }

    // then - verify order hasn't changed (since first item was already at head)
    #expect(secondIteration.count == 3)
    #expect(secondIteration[0].0 == firstKey)
    #expect(secondIteration[0].1 == "third")
    #expect(secondIteration[1].1 == "second")
    #expect(secondIteration[2].1 == "first")
  }

  @Test("Remove item from middle of queue")
  func removeItemFromMiddle() async throws {
    // given
    let sut = LRUQueue<String>()
    sut.insert("first")
    let secondKey = sut.insert("second")
    sut.insert("third")

    // when - remove the middle item
    let removed = sut.remove(secondKey)

    // when - iterate over the list
    var items = [String]()
    for item in sut {
      items.append(item.1)
    }

    // then - verify the middle item is removed
    #expect(items == ["third", "first"])
    #expect(removed == "second")
  }

  @Test("Remove non-existent key does not affect queue")
  func removeNonExistentKey() async throws {
    // given
    let sut = LRUQueue<String>()
    sut.insert("first")
    sut.insert("second")

    // when - remove a key that doesn't exist
    let removed = sut.remove(999)

    // when - iterate over the list
    var items = [String]()
    for item in sut {
      items.append(item.1)
    }

    // then - verify queue is unchanged
    #expect(items.count == 2)
    #expect(items == ["second", "first"])
    #expect(removed == nil)
  }
}
