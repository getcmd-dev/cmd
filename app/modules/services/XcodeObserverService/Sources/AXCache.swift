// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import ThreadSafe

// MARK: - AXCache

/// A thread-safe cache for Accessibility API (AX) queries.
///
/// The AX cache is designed to improve performance when querying application state through macOS Accessibility APIs.
/// These API calls are expensive operations that can cause the queried application (like Xcode) to freeze or become
/// unresponsive during the query. By caching the results, we reduce the frequency of these expensive calls and
/// improve the overall user experience, especially when working with large projects.
///
/// The cache automatically invalidates entries after 10 minutes to balance memory usage with performance benefits.
/// Cached values are also validated to ensure they still point to valid UI elements before being returned.
@ThreadSafe
final class AXCache: Sendable {
  init() { }

  static let shared = AXCache()

  /// Retrieves or computes a cached array of AX UI elements.
  ///
  /// This method checks if a valid cached value exists for the given element and cache key. If found, it returns
  /// the cached value immediately, avoiding expensive AX API calls. If not found or if the cached elements are
  /// no longer valid, it invokes the fetcher to query the application state and caches the result.
  ///
  /// - Parameters:
  ///   - from: The AX UI element to query from
  ///   - operation: A closure that performs the expensive AX API query when cache misses occur
  ///   - cacheKey: A unique identifier for this specific query (e.g., "children", "windows")
  /// - Returns: An array of AX UI elements, either from cache or freshly fetched
  func caching(from: AXUIElement, _ operation: @Sendable (AXUIElement) -> [AXUIElement], cacheKey: String) -> [AXUIElement] {
    inLock { state in
      defer {
        // Schedule a cleanup task to remove the cached value after 10 minutes, to avoid keeping things in memory for too long while providing good caching.
        let cleanUpTask = Task { [weak self] in
          try? await Task.sleep(for: .seconds(600))
          try Task.checkCancellation()
          self?.inLock { state in
            state.cache[from]?.removeValue(forKey: cacheKey)
            state.cleanupTasks[from]?.removeValue(forKey: cacheKey)
            if state.cache[from]?.isEmpty == true {
              state.cache.removeValue(forKey: from)
            }
            if state.cleanupTasks[from]?.isEmpty == true {
              state.cleanupTasks.removeValue(forKey: from)
            }
          }
        }
        state.cleanupTasks[from, default: [:]][cacheKey] = AnyCancellable {
          cleanUpTask.cancel()
        }
      }

      var cachedValue = state.cache[from]?[cacheKey]
      if cachedValue?.allSatisfy(\.isValid) != true {
        state.cache[from]?.removeValue(forKey: cacheKey)
        cachedValue = nil
      }
      if let cachedValue {
        return cachedValue
      }
      let fetched = operation(from)
      state.cache[from, default: [:]][cacheKey] = fetched
      return fetched
    }
  }

  /// Stores cached AX UI elements indexed by source element and cache key.
  private var cache = [AXUIElement: [String: [AXUIElement]]]()

  /// Stores cleanup tasks that invalidate cache entries after 10 minutes.
  private var cleanupTasks = [AXUIElement: [String: AnyCancellable]]()

}

extension AXUIElement {
  /// Retrieves or computes a cached array of AX UI elements for this element.
  ///
  /// Convenience method that calls the shared AX cache with this element as the source.
  ///
  /// - Parameters:
  ///   - operation: A closure that performs the expensive AX API query when cache misses occur
  ///   - cacheKey: A unique identifier for this specific query
  /// - Returns: An array of AX UI elements, either from cache or freshly fetched
  func caching(_ operation: @Sendable (AXUIElement) -> [AXUIElement], cacheKey: String) -> [AXUIElement] {
    AXCache.shared.caching(from: self, operation, cacheKey: cacheKey)
  }

  /// Retrieves or computes a cached optional AX UI element for this element.
  ///
  /// Convenience method for queries that return a single optional element. Internally wraps the result
  /// in an array for caching and extracts the first element.
  ///
  /// - Parameters:
  ///   - operation: A closure that performs the expensive AX API query when cache misses occur
  ///   - cacheKey: A unique identifier for this specific query
  /// - Returns: An optional AX UI element, either from cache or freshly fetched
  func caching(_ operation: @Sendable (AXUIElement) -> AXUIElement?, cacheKey: String) -> AXUIElement? {
    AXCache.shared.caching(from: self, {
      [operation($0)].compactMap(\.self)
    }, cacheKey: cacheKey).first
  }

  /// Retrieves or computes a cached AX UI element for this element.
  ///
  /// Convenience method for queries that always return a single element. Internally wraps the result
  /// in an array for caching and extracts the first element. Falls back to calling the operation if
  /// the cache returns an empty array (though this should not occur in practice).
  ///
  /// - Parameters:
  ///   - operation: A closure that performs the expensive AX API query when cache misses occur
  ///   - cacheKey: A unique identifier for this specific query
  /// - Returns: An AX UI element, either from cache or freshly fetched
  func caching(_ operation: @Sendable (AXUIElement) -> AXUIElement, cacheKey: String) -> AXUIElement {
    AXCache.shared.caching(from: self, {
      [operation($0)].compactMap(\.self)
    }, cacheKey: cacheKey).first ?? operation(self) // The later fallback cannot be executed, but it reads better than `!`.
  }
}
