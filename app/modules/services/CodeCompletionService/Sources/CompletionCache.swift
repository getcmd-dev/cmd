// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Foundation
import ThreadSafe

// MARK: - CompletionCacheRequest

/// Represents a code completion request used for caching
struct CompletionCacheRequest: Sendable, Hashable {
  let file: URL
  let content: String
  let selection: CodeCompletionFoundation.Range
}

// MARK: - CompletionCache

/// A cache that stores code completion suggestions with support for partial match lookups.
///
/// This cache implements a multi-key lookup strategy where a single cached result can be
/// retrieved using multiple cache keys. This is useful for scenarios where the user continues
/// typing after a completion is cached, and the new state matches a partial application of
/// the cached completion.
///
/// Example:
/// If content is "print hello" with cursor at the end, and a cached completion suggests
/// "hello world", then when the user types "w" to get "print hellow" (with cursor after 'w'),
/// the cache recognizes this as a partial match and returns the same cached completion.
@ThreadSafe
final class CompletionCache: Sendable {
  nonisolated init(maxEntries: Int = 100) {
    self.maxEntries = maxEntries
  }

  struct CachedSuggestion {
    let fileURL: URL
    let prefix: String
    let suffix: String
    let completion: AppliedCompletionSuggestion
  }

  func store(suggestion: AppliedCompletionSuggestion, for request: CompletionCacheRequest) {
    let oldContent = request.content
    let newContent = suggestion.newContent
    let prefix = oldContent.commonPrefix(with: newContent)
    let suffix = oldContent.commonSuffix(with: newContent)
    cachedSuggestions.insert(.init(fileURL: request.file, prefix: prefix, suffix: suffix, completion: suggestion))
  }

  func get(for request: CompletionCacheRequest) -> CodeCompletionServiceInterface.CompletionSuggestion? {
    let content = request.content
    for (k, cached) in cachedSuggestions {
      if cached.fileURL != request.file { continue }
      if !content.hasPrefix(cached.prefix) || !content.hasSuffix(cached.suffix) { continue }
      let changedRange = changedRange(content: request.content, prefix: cached.prefix, suffix: cached.suffix)
      if !changedRange.contains(request.selection) { continue }
      let middleContent = String(content.dropFirst(cached.prefix.count).dropLast(cached.suffix.count))
      if middleContent.matches(cached.completion.diff) {
        cachedSuggestions.use(k)
        return cached.completion.applied(to: request, changedRange: changedRange)
      }
    }
    return nil
  }

  // TODO: find the right way to store/index this data
  private var cachedSuggestions = LRUQueue<CachedSuggestion>()

  private let maxEntries: Int

  private func changedRange(content: String, prefix: String, suffix: String) -> Range {
    let oldContent = content
    let oldLines = oldContent.splitLines()

    let prefixLines = prefix.splitLines()
    let suffixLines = suffix.splitLines()

    let startPosition = Position(line: prefixLines.count - 1, character: prefixLines.last?.count ?? 0)
    let endPosition = Position(
      line: oldLines.count - suffixLines.count,
      character: (oldLines[safe: oldLines.count - suffixLines.count]?.count ?? 0) -
        (suffixLines.first?.count ?? 0))

    return Range(start: startPosition, end: endPosition)
  }

}

extension StringProtocol {
  func commonSuffix(with string: some StringProtocol) -> String {
    var matchingLength = 0
    let minLength = Swift.min(count, string.count)
    for i in 0..<minLength {
      if self[index(endIndex, offsetBy: -i - 1)] == string[string.index(string.endIndex, offsetBy: -i - 1)] {
        matchingLength += 1
      } else {
        break
      }
    }
    return String(self[index(endIndex, offsetBy: -matchingLength)..<endIndex])
  }
}

typealias Diff = [CodeCompletionServiceInterface.CompletionSuggestion.LineChange]
typealias InlineDiff = [CodeCompletionServiceInterface.CompletionSuggestion.LineChange.WordChange]

extension Diff {
  var inline: InlineDiff {
    var result: InlineDiff = []
    var lastChange: InlineDiff.Element? = nil
    for lineChange in self {
      for wordChange in lineChange.changes {
        if lastChange?.type == wordChange.type {
          // Merge with last
          lastChange = InlineDiff.Element(
            text: lastChange!.text + wordChange.text,
            type: wordChange.type)
        } else {
          // New change
          if let lastChange {
            result.append(lastChange)
          }
          lastChange = wordChange
        }
      }
    }
    if let lastChange {
      result.append(lastChange)
    }
    return result
  }
}

extension StringProtocol {
  /// Returns whether the string corresponds to the diff partially applied.
  /// Example:
  /// - diff: "hello [+world+]"
  ///     "hello " -> true
  ///     "hello w" -> true
  ///     "hello wo" -> true
  ///     "hello o" -> true  (any part of the added/removed segment is acceptable)
  ///     "ello world" -> false
  func matches(_ diff: Diff) -> Bool {
    matches(Array(diff.inline.trimming(while: { $0.type == .unchanged })))
  }

  func matches(_ diff: InlineDiff) -> Bool {
    let cand = Array(self)
    let M = cand.count

    // Flatten segments to:
    // - allChars: all diff chars
    // - requiredChars: only unchanged chars
    // - flat: (char, required)
    var allChars = [Character]()
    var requiredChars = [Character]()
    var flat = [(ch: Character, required: Bool)]()

    allChars.reserveCapacity(diff.reduce(0) { $0 + $1.text.count })
    flat.reserveCapacity(allChars.capacity)

    for segment in diff {
      let isRequired = (segment.type == .unchanged)
      for ch in segment.text {
        allChars.append(ch)
        flat.append((ch, isRequired))
        if isRequired {
          requiredChars.append(ch)
        }
      }
    }

    // Quick length checks
    if requiredChars.count > M { return false }
    if M > allChars.count { return false }

    // Quick subsequence checks
    if !isSubsequence(requiredChars, in: cand) { return false }
    if !isSubsequence(cand, in: allChars) { return false }

    let N = flat.count
    if N == 0 {
      return M == 0 // no diff chars → only empty candidate is valid
    }

    // Precompute suffix counts of remaining required chars
    var requiredSuffix = [Int](repeating: 0, count: N + 1)
    for i in stride(from: N - 1, through: 0, by: -1) {
      requiredSuffix[i] = requiredSuffix[i + 1] + (flat[i].required ? 1 : 0)
    }

    // DP over candidate length
    var dp = [Bool](repeating: false, count: M + 1)
    var next = [Bool](repeating: false, count: M + 1)
    dp[0] = true
    var minJ = 0
    var maxJ = 0

    func resetNext() {
      // We only need to clear within [minJ, maxJ+1], but M+1 is fine
      for i in 0...M {
        next[i] = false
      }
    }

    for i in 0..<N {
      let (ch, required) = flat[i]
      resetNext()

      var nextMinJ = M + 1
      var nextMaxJ = -1

      if required {
        // Required char: must match next candidate char
        if minJ > M - 1 {
          // There's no room to match another char
          return false
        }

        for j in minJ...maxJ where dp[j] {
          if j < M, cand[j] == ch {
            if !next[j + 1] {
              next[j + 1] = true
              if j + 1 < nextMinJ { nextMinJ = j + 1 }
              if j + 1 > nextMaxJ { nextMaxJ = j + 1 }
            }
          }
        }
      } else {
        // Optional char: we can skip or match
        for j in minJ...maxJ where dp[j] {
          // Skip:
          if !next[j] {
            next[j] = true
            if j < nextMinJ { nextMinJ = j }
            if j > nextMaxJ { nextMaxJ = j }
          }
          // Match:
          if j < M, cand[j] == ch, !next[j + 1] {
            next[j + 1] = true
            if j + 1 < nextMinJ { nextMinJ = j + 1 }
            if j + 1 > nextMaxJ { nextMaxJ = j + 1 }
          }
        }
      }

      if nextMaxJ == -1 {
        // No reachable states -> impossible
        return false
      }

      dp = next
      minJ = nextMinJ
      maxJ = nextMaxJ

      // Early success: candidate fully consumed and no required chars left
      if dp[M], requiredSuffix[i + 1] == 0 {
        return true
      }
    }

    // At the end we must have consumed the whole candidate
    return dp[M]
  }

  private func isSubsequence<T: Equatable>(_ small: [T], in big: [T]) -> Bool {
    var i = 0
    var j = 0
    while i < small.count, j < big.count {
      if small[i] == big[j] {
        i += 1
      }
      j += 1
    }
    return i == small.count
  }
}

extension AppliedCompletionSuggestion {
  func applied(to request: CompletionCacheRequest, changedRange: Range) -> AppliedCompletionSuggestion? {
    let completion = diff.inline
      .trimming(while: { $0.type == .unchanged })
      .filter { $0.type != .removed }
      .map(\.text)
      .joined()

    return RawCompletionSuggestion(
      file: request.file,
      startPosition: changedRange.start,
      endPosition: changedRange.end,
      completion: completion,
      id: UUID())
      .applied(to: request.content, file: request.file, selection: request.selection)
  }
}

extension Range {
  func contains(_ other: Range) -> Bool {
    let startsAfter = other.start.line > start.line ||
      (other.start.line == start.line && other.start.character >= start.character)
    let endsBefore = other.end.line < end.line ||
      (other.end.line == end.line && other.end.character <= end.character)
    return startsAfter && endsBefore
  }
}
