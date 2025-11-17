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
}
