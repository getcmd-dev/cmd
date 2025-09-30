// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation

// MARK: - Finding Elements

extension AXUIElement {
  /// Find the first parent element that matches the given condition.
  public func firstParent(where match: (AXUIElement) -> Bool) -> AXUIElement? {
    guard let parent else { return nil }
    if match(parent) { return parent }
    return parent.firstParent(where: match)
  }
}

// MARK: - Tree

public protocol Tree {
  associatedtype Child: Tree where Child.Child == Child
  var children: [Child] { get }
}

// MARK: - TreeSearchNextStep

public enum TreeSearchNextStep {
  case skipDescendants
  case skipSiblings
  case skipDescendantsAndSiblings
  case continueSearching
  case stopSearching
}

extension Tree where Child == Self {

  /// Returns all children in the tree that match the given criteria.
  ///
  /// This method searches through the tree hierarchy and collects children that satisfy
  /// the matching condition. When a child matches, its descendants are not searched.
  ///
  /// - Parameter match: A closure that determines whether a child should be included.
  ///   - Parameters:
  ///     - element: The current tree element being evaluated.
  ///     - level: The depth level in the tree (1-based, starting from direct children).
  ///   - Returns: A `TreeSearchNextStep` indicating how to proceed with the search.
  /// - Returns: An array of matching child elements.
  public func children(where match: (Self, Int) -> TreeSearchNextStep) -> [Self] {
    func _children(
      element: Self,
      where match: (Self, Int) -> TreeSearchNextStep,
      level: Int)
      -> (results: [Self], shouldStop: Bool)
    {
      var all = [Self]()
      var unmatchedChildren = [Self]()
      for child in element.children {
        switch match(child, level) {
        case .stopSearching:
          all.append(child)

        case .skipDescendants:
          break

        case .skipDescendantsAndSiblings:
          return (all, true)

        case .skipSiblings:
          all.append(child)
          return (all, true)

        case .continueSearching:
          unmatchedChildren.append(child)
        }
      }
      for child in unmatchedChildren {
        let (childResults, shouldStop) = _children(element: child, where: match, level: level + 1)
        all.append(contentsOf: childResults)
        if shouldStop {
          return (all, true)
        }
      }
      return (all, false)
    }
    return _children(element: self, where: match, level: 1).results // 1 as we start from the children, not the current element.
  }

  /// Returns the first child in the tree that matches the given criteria.
  ///
  /// This method performs a depth-first search through the tree hierarchy and returns
  /// the first child that satisfies the matching condition.
  ///
  /// - Parameter match: A closure that determines whether a child should be selected.
  ///   - Parameters:
  ///     - element: The current tree element being evaluated.
  ///     - level: The depth level in the tree (1-based, starting from direct children).
  ///   - Returns: A `TreeSearchNextStep` indicating how to proceed with the search.
  /// - Returns: The first matching child element, or `nil` if no match is found.
  public func firstChild(where match: (Self, Int) -> TreeSearchNextStep) -> Self? {
    var result: Self?
    for child in children {
      child.traverse { element, level in
        let nextStep = match(element, level + 1) // +1 as we start from the children, not the current element.
        if nextStep == .stopSearching {
          result = element
        }
        return nextStep
      }
      if let result { return result }
    }
    return nil
  }

  /// Traverses the element tree depth-first, executing a handler for each element.
  ///
  /// This method walks through the entire tree hierarchy, calling the provided handler
  /// for each element. The handler can control the traversal flow by returning different
  /// `TreeSearchNextStep` values.
  ///
  /// - Parameter handle: A closure executed for each element during traversal.
  ///   - Parameters:
  ///     - element: The current tree element being visited.
  ///     - level: The depth level in the tree (0-based, starting from the root element).
  ///   - Returns: A `TreeSearchNextStep` indicating how to continue the traversal.
  ///
  /// - Important: Traversing the element tree is resource consuming and will affect the
  ///   **performance of Xcode**. Please make sure to skip as much as possible.
  public func traverse(_ handle: (_ element: Self, _ level: Int) -> TreeSearchNextStep) {
    func _traverse(
      element: Self,
      level: Int,
      handle: (Self, Int) -> TreeSearchNextStep)
      -> TreeSearchNextStep
    {
      let nextStep = handle(element, level)
      switch nextStep {
      case .stopSearching: return .stopSearching
      case .skipDescendants: return .continueSearching
      case .skipDescendantsAndSiblings: return .skipSiblings
      case .continueSearching, .skipSiblings:
        childrenLoop: for child in element.children {
          switch _traverse(element: child, level: level + 1, handle: handle) {
          case .skipSiblings, .skipDescendantsAndSiblings:
            break childrenLoop
          case .stopSearching:
            return .stopSearching
          case .continueSearching, .skipDescendants:
            continue
          }
        }
        return nextStep
      }
    }
    _ = _traverse(element: self, level: 0, handle: handle)
  }
}
