// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import AccessibilityFoundation

// MARK: - TestNode

/// A simple tree structure for testing the Tree protocol
struct TestNode: Tree, Equatable {
  let id: String
  let children: [TestNode]

  init(id: String, children: [TestNode] = []) {
    self.id = id
    self.children = children
  }
}

// MARK: - TreeTests

@Suite("Tree Protocol Tests")
struct TreeTests {

  // MARK: - children(where:) Tests

  @Test("children(where:) returns matching children at first level")
  func test_children_returnsMatchingChildrenAtFirstLevel() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.children { node, _ in
      node.id == "a" ? .stopSearching : .continueSearching
    }

    // then
    #expect(result.count == 1)
    #expect(result.first?.id == "a")
  }

  @Test("children(where:) returns multiple matches from different levels")
  func test_children_returnsMultipleMatches() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.children { node, _ in
      // Match "a" and "b1a", "a" will prevent searching "a1" and "a2"
      node.id.hasPrefix("a") || node.id == "b1a" ? .stopSearching : .continueSearching
    }

    // then
    // "a" matches, so "a1" and "a2" are not searched (descendants of matched node)
    // "b1a" also matches and is found
    #expect(result.count == 2)
    #expect(result.map(\.id).sorted() == ["a", "b1a"])
  }

  @Test("children(where:) does not search descendants of matched nodes")
  func test_children_doesNotSearchDescendantsOfMatchedNodes() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.children { node, _ in
      node.id == "a" ? .stopSearching : .continueSearching
    }

    // then
    // Should only return "a", not "a1" or "a2"
    #expect(result.count == 1)
    #expect(result.first?.id == "a")
  }

  @Test("children(where:) skipDescendants skips that subtree")
  func test_children_skipDescendantsSkipsThatSubtree() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.children { node, _ in
      if node.id == "a" {
        return .skipDescendants
      }
      return node.id.hasPrefix("a") ? .stopSearching : .continueSearching
    }

    // then
    // Should not find a1 or a2 because we skipped "a"'s descendants
    #expect(result.isEmpty)
  }

  @Test("children(where:) skipSiblings stops sibling search")
  func test_children_skipSiblingsStopsSiblingSearch() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.children { node, _ in
      if node.id == "a1" {
        return .skipSiblings
      }
      if node.id == "a2" {
        return .stopSearching
      }
      return .continueSearching
    }

    // then
    // "a1" returns skipSiblings, so it's added and "a2" is not checked
    #expect(result.count == 1)
    #expect(result.first?.id == "a1")
  }

  @Test("children(where:) skipDescendantsAndSiblings stops immediately")
  func test_children_skipDescendantsAndSiblingsStopsImmediately() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.children { node, _ in
      if node.id == "a1" {
        return .skipDescendantsAndSiblings
      }
      if node.id == "a2" {
        return .stopSearching
      }
      return .continueSearching
    }

    // then
    // "a1" returns skipDescendantsAndSiblings, so we don't check "a2"
    #expect(result.isEmpty)
  }

  @Test("children(where:) provides correct level parameter")
  func test_children_providesCorrectLevel() {
    // given
    let sut = createSimpleTree()
    var levels = [String: Int]()

    // when
    _ = sut.children { node, level in
      levels[node.id] = level
      return .continueSearching
    }

    // then
    #expect(levels["a"] == 1)
    #expect(levels["b"] == 1)
    #expect(levels["a1"] == 2)
    #expect(levels["a2"] == 2)
    #expect(levels["b1"] == 2)
    #expect(levels["b1a"] == 3)
  }

  // MARK: - firstChild(where:) Tests

  @Test("firstChild(where:) returns first matching child")
  func test_firstChild_returnsFirstMatchingChild() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.firstChild { node, _ in
      node.id.hasPrefix("a") ? .stopSearching : .continueSearching
    }

    // then
    #expect(result?.id == "a")
  }

  @Test("firstChild(where:) returns deeply nested match")
  func test_firstChild_returnsDeeplyNestedMatch() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.firstChild { node, _ in
      node.id == "b1a" ? .stopSearching : .continueSearching
    }

    // then
    #expect(result?.id == "b1a")
  }

  @Test("firstChild(where:) returns nil when no match")
  func test_firstChild_returnsNilWhenNoMatch() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.firstChild { node, _ in
      node.id == "nonexistent" ? .stopSearching : .continueSearching
    }

    // then
    #expect(result == nil)
  }

  @Test("firstChild(where:) respects skipDescendants")
  func test_firstChild_respectsSkipDescendants() {
    // given
    let sut = createSimpleTree()

    // when
    let result = sut.firstChild { node, _ in
      if node.id == "a" {
        return .skipDescendants
      }
      return node.id == "a1" ? .stopSearching : .continueSearching
    }

    // then
    // Should not find "a1" because we skipped "a"'s descendants
    #expect(result == nil)
  }

  @Test("firstChild(where:) provides correct level parameter")
  func test_firstChild_providesCorrectLevel() {
    // given
    let sut = createSimpleTree()
    var capturedLevel: Int?

    // when
    _ = sut.firstChild { node, level in
      if node.id == "b1a" {
        capturedLevel = level
        return .stopSearching
      }
      return .continueSearching
    }

    // then
    #expect(capturedLevel == 3)
  }

  // MARK: - traverse(_:) Tests

  @Test("traverse(_:) visits all nodes")
  func test_traverse_visitsAllNodes() {
    // given
    let sut = createSimpleTree()
    var visited = [String]()

    // when
    sut.traverse { node, _ in
      visited.append(node.id)
      return .continueSearching
    }

    // then
    #expect(visited.count == 7) // root + 6 descendants
    #expect(visited.contains("root"))
    #expect(visited.contains("a"))
    #expect(visited.contains("a1"))
    #expect(visited.contains("a2"))
    #expect(visited.contains("b"))
    #expect(visited.contains("b1"))
    #expect(visited.contains("b1a"))
  }

  @Test("traverse(_:) respects stopSearching")
  func test_traverse_respectsStopSearching() {
    // given
    let sut = createSimpleTree()
    var visited = [String]()

    // when
    sut.traverse { node, _ in
      visited.append(node.id)
      if node.id == "a1" {
        return .stopSearching
      }
      return .continueSearching
    }

    // then
    // Should stop after finding "a1"
    #expect(visited.contains("root"))
    #expect(visited.contains("a"))
    #expect(visited.contains("a1"))
    #expect(!visited.contains("a2")) // Should not visit remaining nodes
  }

  @Test("traverse(_:) respects skipDescendants")
  func test_traverse_respectsSkipDescendants() {
    // given
    let sut = createSimpleTree()
    var visited = [String]()

    // when
    sut.traverse { node, _ in
      visited.append(node.id)
      if node.id == "a" {
        return .skipDescendants
      }
      return .continueSearching
    }

    // then
    #expect(visited.contains("a"))
    #expect(!visited.contains("a1")) // Descendants of "a" should be skipped
    #expect(!visited.contains("a2"))
    #expect(visited.contains("b")) // But siblings should still be visited
    #expect(visited.contains("b1"))
  }

  @Test("traverse(_:) respects skipSiblings")
  func test_traverse_respectsSkipSiblings() {
    // given
    let sut = createSimpleTree()
    var visited = [String]()

    // when
    sut.traverse { node, _ in
      visited.append(node.id)
      if node.id == "a" {
        return .skipSiblings
      }
      return .continueSearching
    }

    // then
    #expect(visited.contains("a"))
    #expect(visited.contains("a1")) // Descendants should be visited
    #expect(visited.contains("a2"))
    #expect(!visited.contains("b")) // Siblings should be skipped
    #expect(!visited.contains("b1"))
  }

  @Test("traverse(_:) respects skipDescendantsAndSiblings")
  func test_traverse_respectsSkipDescendantsAndSiblings() {
    // given
    let sut = createSimpleTree()
    var visited = [String]()

    // when
    sut.traverse { node, _ in
      visited.append(node.id)
      if node.id == "a" {
        return .skipDescendantsAndSiblings
      }
      return .continueSearching
    }

    // then
    #expect(visited.contains("root"))
    #expect(visited.contains("a"))
    #expect(!visited.contains("a1")) // Descendants should be skipped
    #expect(!visited.contains("a2"))
    #expect(!visited.contains("b")) // Siblings should be skipped
    #expect(!visited.contains("b1"))
  }

  @Test("traverse(_:) provides correct level parameter")
  func test_traverse_providesCorrectLevel() {
    // given
    let sut = createSimpleTree()
    var levels = [String: Int]()

    // when
    sut.traverse { node, level in
      levels[node.id] = level
      return .continueSearching
    }

    // then
    #expect(levels["root"] == 0)
    #expect(levels["a"] == 1)
    #expect(levels["b"] == 1)
    #expect(levels["a1"] == 2)
    #expect(levels["a2"] == 2)
    #expect(levels["b1"] == 2)
    #expect(levels["b1a"] == 3)
  }

  @Test("traverse(_:) traverses depth-first")
  func test_traverse_traversesDepthFirst() {
    // given
    let sut = createSimpleTree()
    var visited = [String]()

    // when
    sut.traverse { node, _ in
      visited.append(node.id)
      return .continueSearching
    }

    // then
    // Depth-first means we should visit a node before its siblings
    let aIndex = visited.firstIndex(of: "a")!
    let a1Index = visited.firstIndex(of: "a1")!
    let a2Index = visited.firstIndex(of: "a2")!
    let bIndex = visited.firstIndex(of: "b")!

    #expect(aIndex < a1Index) // "a" before "a1"
    #expect(aIndex < a2Index) // "a" before "a2"
    #expect(a1Index < bIndex) // "a1" before "b"
    #expect(a2Index < bIndex) // "a2" before "b"
  }

  // MARK: - Edge Cases

  @Test("Tree functions work with empty children")
  func test_treeFunctions_workWithEmptyChildren() {
    // given
    let sut = TestNode(id: "leaf", children: [])

    // when/then - should not crash
    let children = sut.children { _, _ in .stopSearching }
    #expect(children.isEmpty)

    let firstChild = sut.firstChild { _, _ in .stopSearching }
    #expect(firstChild == nil)

    var visitedCount = 0
    sut.traverse { _, _ in
      visitedCount += 1
      return .continueSearching
    }
    #expect(visitedCount == 1) // Only the root node
  }

  @Test("Tree functions work with single-level tree")
  func test_treeFunctions_workWithSingleLevel() {
    // given
    let sut = TestNode(
      id: "root",
      children: [
        TestNode(id: "child1"),
        TestNode(id: "child2"),
        TestNode(id: "child3"),
      ])

    // when
    let children = sut.children { node, _ in
      node.id == "child2" ? .stopSearching : .continueSearching
    }

    // then
    #expect(children.count == 1)
    #expect(children.first?.id == "child2")
  }

  @Test("Tree functions work with deeply nested tree")
  func test_treeFunctions_workWithDeeplyNestedTree() {
    // given - create a chain: root -> a -> b -> c -> d -> e
    let sut = TestNode(
      id: "root",
      children: [
        TestNode(
          id: "a",
          children: [
            TestNode(
              id: "b",
              children: [
                TestNode(
                  id: "c",
                  children: [
                    TestNode(
                      id: "d",
                      children: [
                        TestNode(id: "e"),
                      ]),
                  ]),
              ]),
          ]),
      ])

    // when
    let result = sut.firstChild { node, level in
      if node.id == "e" {
        #expect(level == 5)
        return .stopSearching
      }
      return .continueSearching
    }

    // then
    #expect(result?.id == "e")
  }

  // MARK: - Test Fixtures

  /// Creates a simple tree structure:
  ///     root
  ///     ├─ a
  ///     │  ├─ a1
  ///     │  └─ a2
  ///     └─ b
  ///        └─ b1
  ///           └─ b1a
  private func createSimpleTree() -> TestNode {
    TestNode(
      id: "root",
      children: [
        TestNode(
          id: "a",
          children: [
            TestNode(id: "a1"),
            TestNode(id: "a2"),
          ]),
        TestNode(
          id: "b",
          children: [
            TestNode(
              id: "b1",
              children: [
                TestNode(id: "b1a"),
              ]),
          ]),
      ])
  }

}
