// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
import ThreadSafe

// MARK: - CompletionCacheRequest

/// Represents a code completion request used for caching
struct CompletionCacheRequest: Sendable, Hashable {
  let workspace: URL
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
    let workspaceURL: URL
    let fileURL: URL
    let prefix: String
    let suffix: String
    let completion: CompletionSuggestion?
  }

  func store(suggestion: CompletionSuggestion?, for request: CompletionCacheRequest) -> Int {
    if let suggestion {
      let oldContent = request.content
      let newContent = suggestion.newContent
      let prefix = oldContent.commonPrefix(with: newContent)
      let suffix = oldContent.commonSuffix(with: newContent)
      return cachedSuggestions.insert(.init(
        workspaceURL: request.workspace,
        fileURL: request.file,
        prefix: prefix,
        suffix: suffix,
        completion: suggestion))
    } else {
      let content = request.content
      let lines = content.splitLines()
      let lineOffsets = lines.reduce(into: [0], { acc, l in
        acc.append((acc.last ?? 0) + l.count)
      })
      let cursorOffset = lineOffsets[request.selection.start.line] + request.selection.start.character
      let prefix = String(content.prefix(upTo: content.index(content.startIndex, offsetBy: cursorOffset)))
      let suffix = String(content.suffix(from: content.index(content.startIndex, offsetBy: cursorOffset)))
      return cachedSuggestions.insert(.init(
        workspaceURL: request.workspace,
        fileURL: request.file,
        prefix: prefix,
        suffix: suffix,
        completion: nil))
    }
  }

  func get(for request: CompletionCacheRequest)
    -> (cacheId: Int, suggestion: CodeCompletionServiceInterface.CompletionSuggestion?)?
  {
    let content = request.content
    for (k, cached) in cachedSuggestions {
      if cached.workspaceURL != request.workspace || cached.fileURL != request.file { continue }
      if !content.hasPrefix(cached.prefix) || !content.hasSuffix(cached.suffix) { continue }
      let changedRange = changedRange(content: request.content, prefix: cached.prefix, suffix: cached.suffix)
      if !changedRange.contains(request.selection) { continue }
      let middleContent = String(content.dropFirst(cached.prefix.count).dropLast(cached.suffix.count))
      if let completion = cached.completion {
        if middleContent.matches(Array(completion.diff.inline.trimming(while: { $0.type == .unchanged }))) {
          cachedSuggestions.use(k)
          if let suggestion = completion.applied(to: request, changedRange: changedRange) {
            return (cacheId: k, suggestion: suggestion)
          } else {
            return nil
          }
        }
      } else if middleContent.isEmpty {
        cachedSuggestions.use(k)
        return (cacheId: k, suggestion: nil)
      }
    }
    return nil
  }

  func remove(cachedRequestId: Int) {
    cachedSuggestions.remove(cachedRequestId)
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
    utf8.withContiguousStorageIfAvailable { selfBuf in
      String(string).utf8.withContiguousStorageIfAvailable { otherBuf in
        let minLength = Swift.min(selfBuf.count, otherBuf.count)
        for i in 0..<minLength {
          if selfBuf[selfBuf.count - 1 - i] == otherBuf[otherBuf.count - 1 - i] {
            matchingLength += 1
          } else {
            break
          }
        }
      }
    }
    return String(decoding: utf8.suffix(matchingLength), as: UTF8.self)
  }
}

typealias Diff = [CodeCompletionServiceInterface.CompletionSuggestion.LineChange]
typealias InlineDiff = [CharacterLevelChange]

extension [[CharacterLevelChange]] {
  var inline: InlineDiff {
    var result: InlineDiff = []
    var lastChange: InlineDiff.Element? = nil
    for lineChange in self {
      for wordChange in lineChange {
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

extension Diff {
  var inline: InlineDiff {
    map(\.changes).inline
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
  func matches(_ diff: InlineDiff) -> Bool {
    let unchangedDiffPrefix = diff.prefix(while: { $0.type == .unchanged })
    if unchangedDiffPrefix.count == diff.count {
      // All unchanged
      return self == diff.map(\.text).joined()
    }
    let unchangedDiffSuffix = diff.suffix(while: { $0.type == .unchanged })
    let changedDiff = diff[unchangedDiffPrefix.count..<diff.count - unchangedDiffSuffix.count]
    let unchangedPrefix = unchangedDiffPrefix.map(\.text).joined()
    let unchangedSuffix = unchangedDiffSuffix.map(\.text).joined()
    if !hasPrefix(unchangedPrefix) || !hasSuffix(unchangedSuffix) { return false }
    if unchangedPrefix.count + unchangedSuffix.count == count {
      return changedDiff.allSatisfy({ $0.type != .unchanged })
    }
    let matchedRange = index(startIndex, offsetBy: unchangedPrefix.count)..<index(endIndex, offsetBy: -unchangedSuffix.count)
    return self[matchedRange].matchesChangedOnly(Array(changedDiff))
  }

  private func matchesChangedOnly(_ diff: InlineDiff) -> Bool {
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

    var hasTestedSimplicity = false
    // Validate that the change from the current content to the target content is simpler than the original one.
    // The git diff is likely more expensive than the compute as it calls into a subprocess, so we run it once before returning true.
    // This validation prevents accepting content that quite clearly doesn't correspond to the user making progress from the cached content to the suggested content, ie:
    // "hello you" matches? "hello [+some extremely long suggested content+]" -> false even though we could find a subset like:
    // "hello [+some extremel+]y[+ l+]o[+ng s+]u[+ggested content+]"

    let testNewChangeIsSimpler = {
      if hasTestedSimplicity { return true }
      hasTestedSimplicity = true

      // Quick verification that the diff didn
      let targetContent = diff.filter { $0.type != .removed }.map(\.text).joined()
      let oldContent = String(self)
      guard let newDiff = try? FileDiff.getCharacterDiff(oldContent: oldContent, newContent: targetContent) else {
        return false
      }
      let newChange = FileDiff.characterDiffToLineChanges(
        diff: newDiff,
        oldContent: oldContent,
        newContent: targetContent).lineChanges.inline
      if
        newChange.filter({ $0.type != .unchanged }).count > diff.filter({ $0.type != .unchanged }).count || newChange.map(\.text)
          .joined().count > diff.map(\.text).joined().count { return false }
      return true
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
        if !testNewChangeIsSimpler() { return false }
        return true
      }
    }

    // At the end we must have consumed the whole candidate
    if !dp[M] { return false }
    if !testNewChangeIsSimpler() { return false }
    return true
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

extension CompletionSuggestion {
  func applied(to request: CompletionCacheRequest, changedRange: Range) -> CompletionSuggestion? {
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
