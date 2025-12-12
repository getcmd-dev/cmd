// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
import Testing
@testable import CodeCompletionService

// MARK: - CompletionCacheTests

@Suite("CompletionCacheTests")
struct CompletionCacheTests {

  struct DiffMatchesTests {

    @Test
    func basic_acceptsExpectedVariants() throws {
      let diff = try getInlineChanges(from: "test some function", to: "test function foo") // test {-some -}function{+ foo+}
      #expect("test some function".matches(diff)) // keep removed, keep unchanged, skip added
      #expect("test function foo".matches(diff)) // delete removed, keep unchanged, type added
      #expect("test function".matches(diff)) // delete removed, keep unchanged, skip added
      #expect("test function fo".matches(diff)) // delete removed, keep unchanged, partial added
      #expect("test some function foo".matches(diff)) // keep all
    }

    @Test
    func basic_rejectsInvalidVariants() throws {
      let diff = try getInlineChanges(from: "test some function", to: "test function foo") // test {-some -}function{+ foo+}

      #expect("funcxtion".matches(diff) == false) // 'x' not in diff
      #expect("foo function".matches(diff) == false) // wrong order (skips function)
      #expect("some funcxtion".matches(diff) == false) // invalid char
      #expect("foo".matches(diff) == false) // skips required "function"
    }

    @Test
    func chunkOrders_acceptsExpectedVariants() throws {
      let diff = try getInlineChanges(
        from: "test test foo foo",
        to: "test test test test") // test test {-foo-}{+test+} {-foo-}{+test+}

      #expect("test test foo foo".matches(diff)) // original (keep all removed, keep unchanged space)
      #expect("test test test test".matches(diff)) // new (skip removed, keep added, keep unchanged space)
      #expect("test test foo test"
        .matches(diff)) // keep first removed, skip first added, keep unchanged, skip second removed, type second added
      #expect("test test  ".matches(diff)) // skip both removed, skip both added, keep only the unchanged space
    }

    @Test
    func chunkOrders_rejectsInvalidVariants() throws {
      let diff = try getInlineChanges(
        from: "test test foo foo",
        to: "test test test test") // test test {-foo-}{+test+} {-foo-}{+test+}

      #expect("test foo".matches(diff) == false) // can't interleave like this
      #expect("foo test foo".matches(diff) == false) // wrong pattern
    }

    @Test
    func unchangedSuffix_trimmedAway() throws {
      let diff = try getInlineChanges(from: "bbaa", to: "aabbaa") // {+aa+}bbaa
      #expect("bbaa".matches(diff)) // unchanged
      #expect("aabbaa".matches(diff)) // type the added "aa"
      #expect("abbaa".matches(diff)) // partial added
    }

    @Test
    func addedThenUnchanged_oneA() throws {
      let diff = try getInlineChanges(from: "a", to: "aa") // a{+a+}

      #expect("a".matches(diff)) // skip the added part
      #expect("aa".matches(diff)) // include the added "a"
      #expect("ab".matches(diff) == false) // invalid char
    }

    @Test
    func multipleUnchangedBlocks_trimmedAway() throws {
      let diff = try getInlineChanges(from: "abcd", to: "abXYcd") // ab{+XY+}cd

      #expect("abcd".matches(diff)) // skip added
      #expect("abXYcd".matches(diff)) // type all added
      #expect("abXcd".matches(diff)) // partial added

      // Invalid:
      #expect("cd".matches(diff) == false) // "cd" was trimmed, not in diff
      #expect("XYcd".matches(diff) == false) // can't type "cd" (not in diff)
    }

    // MARK: - Only unchanged segments

    @Test
    func onlyUnchangedSegments() throws {
      let diff = Array([CharacterLevelChange(text: "hello", type: .unchanged)])

      #expect("hello".matches(diff)) // empty matches empty
      #expect("hello world".matches(diff) == false) // can't match non-empty to empty
    }

    // MARK: - Stress Tests for matches() Algorithm

    @Test("matches handles empty diff")
    func matchesHandlesEmptyDiff() throws {
      // given
      let diff: InlineDiff = []

      // when/then
      #expect("".matches(diff))
      #expect(!"non-empty".matches(diff))
    }

    @Test("matches handles unicode emoji")
    func matchesHandlesUnicodeEmoji() throws {
      // given
      let oldContent = "let x = 1"
      let newContent = "let x = 😀"
      let diff = try getInlineChanges(from: oldContent, to: newContent) // let x = {-1-}{+😀+}

      #expect("let x = ".matches(diff))
      #expect("let x = 😀".matches(diff))
      #expect(!"let x = 😀extra".matches(diff))
    }

    @Test("matches handles Japanese characters")
    func matchesHandlesJapanese() throws {
      // given
      let oldContent = "let text = hello"
      let newContent = "let text = 日本語"
      let diff = try getInlineChanges(from: oldContent, to: newContent) // let text = {-hello-}{+日本語+}

      #expect("let text = ".matches(diff))
      #expect("let text = 日".matches(diff))
      #expect("let text = 日本".matches(diff))
      #expect("let text = 日本語".matches(diff))
    }

    @Test("matches handles very long strings")
    func matchesHandlesVeryLongStrings() throws {
      // given - create a 5KB diff
      let oldContent = String(repeating: "let x = 1\n", count: 500)
      let newContent = String(repeating: "let y = 2\n", count: 500)
      let diff = try getInlineChanges(from: oldContent, to: newContent) // let {-x-}{+y+} = {-1-}{+2+} (*500)

      // when - test partial match
      let partial = String(repeating: "let ", count: 100)

      // then - should complete without hanging
      _ = partial.matches(diff)
    }

    @Test("matches handles escaped quotes in strings")
    func matchesHandlesEscapedQuotes() throws {
      // given
      let oldContent = "let str = \"hello\""
      let newContent = "let str = \"world\""
      let diff = try getInlineChanges(from: oldContent, to: newContent) // let str = "{-hello-}{+world+}"

      #expect("let str = \"\"".matches(diff)) // skip both
      #expect("let str = \"hello\"".matches(diff)) // keep removed
      #expect("let str = \"world\"".matches(diff)) // skip removed, type added
      #expect("let str = \"helloworld\"".matches(diff)) // keep removed, type added
    }

    @Test("matches handles only first character")
    func matchesHandlesOnlyFirstChar() throws {
      // given
      let oldContent = "hello"
      let newContent = "world"
      let diff = try getInlineChanges(from: oldContent, to: newContent) // {-hello-}{+world+}

      // when/then
      #expect("".matches(diff))
      #expect("w".matches(diff))
      #expect("wo".matches(diff))
      #expect(!"x".matches(diff))
    }

    @Test("matches handles only last character")
    func matchesHandlesOnlyLastChar() throws {
      // given
      let oldContent = "hello"
      let newContent = "helld"
      let diff = try getInlineChanges(from: oldContent, to: newContent) // {-hello-}{+helld+}

      #expect("".matches(diff)) // delete "hello", skip "helld"
      #expect("hello".matches(diff)) // keep "hello", skip "helld"
      #expect("h".matches(diff)) // keep first 'h' of "hello", or delete all and type 'h'
      #expect("helld".matches(diff)) // delete "hello", type all of "helld"
      #expect("helle"
        .matches(
          diff)) // accepted, as the remaining diff is `{-helle-}{+helld+}`. This would be rejected if our simplification algorithm worked off `{-hell-}{+h+}e{+lld+}`
    }

    @Test("matches handles middle segment only")
    func matchesHandlesMiddleSegment() throws {
      // given
      let oldContent = "func test() { old }"
      let newContent = "func test() { new }"
      let diff = try getInlineChanges(from: oldContent, to: newContent) // func test() { {-old-}{+new+} }

      #expect("func test() {  }".matches(diff)) // deleted old, skipped new
      #expect("func test() { n }".matches(diff)) // deleted old, typed 'n'
      #expect("func test() { ne }".matches(diff)) // deleted old, typed "ne"
      #expect("func test() { new }".matches(diff)) // deleted old, typed "new"
      #expect("func test() { old }".matches(diff)) // kept old, skipped new
      #expect(!"func test() { wrong }".matches(diff))
    }

    @Test("matches performance benchmark")
    func matchesPerformanceBenchmark() throws {
      // given - 2KB of changes
      let oldContent = String(repeating: "a", count: 1000) + String(repeating: "b", count: 1000)
      let newContent = String(repeating: "x", count: 1000) + String(repeating: "y", count: 1000)
      let diff = try getInlineChanges(from: oldContent, to: newContent)

      // when - measure performance
      let start = Date()
      let candidate = String(repeating: "x", count: 500)
      let result = candidate.matches(diff)
      let elapsed = Date().timeIntervalSince(start)

      // then - should complete in reasonable time (< 1 second)
      #expect(result == true)
      #expect(elapsed < 1.0, "matches() took \(elapsed)s, expected < 1.0s")
    }

    private func getInlineChanges(from old: String, to new: String) throws -> InlineDiff {
      try Array(CompletionCacheTests.getChanges(from: old, to: new).inline)
    }

  }

  static func getChanges(from old: String, to new: String) throws -> Diff {
    let diffStr = try FileDiff.getCharacterDiff(oldContent: old, newContent: new)
    let (lineChanges, _) = FileDiff.characterDiffToLineChanges(diff: diffStr, oldContent: old, newContent: new)
    return lineChanges.map { lineChanges in
      CodeCompletionServiceInterface.CompletionSuggestion.LineChange(
        changes: lineChanges.map { change in
          CodeCompletionServiceInterface.CompletionSuggestion.LineChange.WordChange(
            text: change.text,
            type: change.type)
        })
    }
  }

  @Test("Cache stores and retrieves exact match")
  func cacheStoresAndRetrievesExactMatch() async throws {
    // given
    let sut = CompletionCache()
    let content = """
      func test() {
        // TODO: implement
      }
      """
    let cursorPosition = Position(line: 1, character: 2)
    let file = URL(fileURLWithPath: "/test.swift")
    let workspace = URL(fileURLWithPath: "/workspace")

    let request = CompletionCacheRequest(
      workspace: workspace,
      file: file,
      content: content,
      selection: .init(start: cursorPosition, end: cursorPosition))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: "  print(0)",
      cursor: .init(line: 1, character: 2),
      changeRange: .init(start: .init(line: 1, character: 0), end: .init(line: 1, character: 20))))

    // when
    _ = sut.store(suggestion: suggestion, for: request)
    let result = sut.get(for: request)

    // then
    let retrieved = try #require(result)
    let retrievedSuggestion = try #require(retrieved.suggestion)
    #expect(retrievedSuggestion.diff.debugDescription == "  {-// TODO: implement-}{+print(0)+}\n")
    #expect(retrievedSuggestion.file == file)
  }

  @Test("Returns converted suggestion")
  func returnsConvertedSuggestion() async throws {
    // given
    let sut = CompletionCache()
    let content = """
      func test() {
        // TODO: implement
      }
      """
    let cursorPosition = Position(line: 1, character: 2)
    let file = URL(fileURLWithPath: "/test.swift")

    let request = CompletionCacheRequest(
      workspace: URL(fileURLWithPath: "/workspace"),
      file: file,
      content: content,
      selection: .init(start: cursorPosition, end: cursorPosition))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: "  print(0)",
      cursor: .init(line: 1, character: 2),
      changeRange: .init(start: .init(line: 1, character: 0), end: .init(line: 1, character: 20))))

    // when
    _ = sut.store(suggestion: suggestion, for: request)
    let newCursorPosition = Position(line: 1, character: 4)
    let newRequest = CompletionCacheRequest(
      workspace: URL(fileURLWithPath: "/workspace"),
      file: file,
      content: """
        func test() {
          pr
        }
        """,
      selection: .init(start: newCursorPosition, end: newCursorPosition))
    let result = sut.get(for: newRequest)

    // then
    let retrieved = try #require(result)
    let retrievedSuggestion = try #require(retrieved.suggestion)
    #expect(retrievedSuggestion.diff.debugDescription == "  pr{+int(0)+}\n")
    #expect(retrievedSuggestion.file == file)
  }

  @Test("Cache rejects lookups outside of changed range")
  func cacheRejectsSelectionOutsideChangedRange() async throws {
    let sut = CompletionCache()
    let file = URL(fileURLWithPath: "/range.swift")
    let content = "hello"
    let cursor = Position(line: 0, character: content.count)
    let request = CompletionCacheRequest(
      workspace: URL(fileURLWithPath: "/workspace"),
      file: file,
      content: content,
      selection: .init(start: cursor, end: cursor))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: " world",
      file: file,
      cursor: cursor))
    _ = sut.store(suggestion: suggestion, for: request)

    let outsideSelection = Position(line: 0, character: 0)
    let lookup = CompletionCacheRequest(
      workspace: URL(fileURLWithPath: "/workspace"),
      file: file,
      content: content,
      selection: .init(start: outsideSelection, end: outsideSelection))

    let result = sut.get(for: lookup)
    #expect(result == nil)
  }

  @Test("Cache keeps entries scoped per file URL")
  func cacheDoesNotMixFiles() async throws {
    let sut = CompletionCache()
    let content = "hello"
    let cursor = Position(line: 0, character: content.count)
    let selection = Range(start: cursor, end: cursor)

    let fileA = URL(fileURLWithPath: "/a.swift")
    let requestA = CompletionCacheRequest(
      workspace: URL(fileURLWithPath: "/workspace"),
      file: fileA,
      content: content,
      selection: selection)
    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: " world",
      file: fileA,
      cursor: cursor))
    _ = sut.store(suggestion: suggestion, for: requestA)

    let fileB = URL(fileURLWithPath: "/b.swift")
    let requestB = CompletionCacheRequest(
      workspace: URL(fileURLWithPath: "/workspace"),
      file: fileB,
      content: content,
      selection: selection)

    let result = sut.get(for: requestB)
    #expect(result == nil)
  }

  @Test("Cache requires prefix match for lookup")
  func cacheRequiresMatchingPrefix() async throws {
    let sut = CompletionCache()
    let file = URL(fileURLWithPath: "/prefix.swift")
    let content = "hello"
    let cursor = Position(line: 0, character: content.count)
    let request = CompletionCacheRequest(
      workspace: URL(fileURLWithPath: "/workspace"),
      file: file,
      content: content,
      selection: .init(start: cursor, end: cursor))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: " world",
      file: file,
      cursor: cursor))
    _ = sut.store(suggestion: suggestion, for: request)

    let mismatchedContent = "HELLO world"
    let mismatchCursor = Position(line: 0, character: mismatchedContent.count)
    let mismatchedRequest = CompletionCacheRequest(
      workspace: URL(fileURLWithPath: "/workspace"),
      file: file,
      content: mismatchedContent,
      selection: .init(start: mismatchCursor, end: mismatchCursor))

    let result = sut.get(for: mismatchedRequest)
    #expect(result == nil)
  }

  /// Our diffing algorithm might interleave existing new lines within the added content, and add new lines at the end.
  /// This test validates that the prefix/suffix match the diff, and that the cache still works in this case.
  @Test("store handles existing newline gettting interleaved within the diff")
  func cacheHandlesDiffWhereSuffixNewlinesAreInDiffBlock() async throws {
    let sut = CompletionCache()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/edge.swift")
    let oldContent = "func \n\n// last line"
    let cursor = Position(line: 0, character: 5)
    let selection = Range(start: cursor, end: cursor)

    let request = CompletionCacheRequest(
      workspace: workspace,
      file: file,
      content: oldContent,
      selection: selection)

    let completionText = "foo() -> Int{\n  return 1\n}\n"

    let suggestion = CompletionSuggestion(
      file: file,
      oldContent: oldContent,
      newContent: completionText,
      newCursorSelection: .init(start: .init(line: 2, character: 2), end: .init(line: 2, character: 2)),
      diffLineStart: 0,
      diff: [
        .init(changes: [
          .init(text: "func ", type: .unchanged),
          .init(text: "foo() -> Int{", type: .added),
          .init(text: "\n", type: .unchanged),
        ]),
        .init(changes: [.init(text: "  return 1", type: .added), .init(text: "\n", type: .unchanged)]),
        .init(changes: [.init(text: "}\n", type: .added)]),
        .init(changes: [.init(text: "\n", type: .added)]),
        .init(changes: [.init(text: "\n", type: .added)]),
      ])

    _ = sut.store(suggestion: suggestion, for: request)

    let newRequest = CompletionCacheRequest(
      workspace: workspace,
      file: file,
      content: "func fo\n\n// last line",
      selection: .init(start: .init(line: 0, character: 8), end: .init(line: 0, character: 8)))

    let result = sut.get(for: newRequest)
    #expect(result?.suggestion != nil)
  }

  @Test("inline diff")
  func testInlineDiff() throws {
    #expect(try CompletionCacheTests.getChanges(from: "print hello", to: "print hello\n world\n")
      .debugDescription == "print hello{+\n world\n+}")
  }

  // MARK: - Remove Tests

  @Test("Remove deletes cached entry by ID")
  func removeDeletesCachedEntryById() async throws {
    // given
    let sut = CompletionCache()
    let content = """
      func test() {
        // TODO: implement
      }
      """
    let cursorPosition = Position(line: 1, character: 2)
    let file = URL(fileURLWithPath: "/test.swift")
    let workspace = URL(fileURLWithPath: "/workspace")

    let request = CompletionCacheRequest(
      workspace: workspace,
      file: file,
      content: content,
      selection: .init(start: cursorPosition, end: cursorPosition))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: "  print(0)",
      cursor: .init(line: 1, character: 2),
      changeRange: .init(start: .init(line: 1, character: 0), end: .init(line: 1, character: 20))))

    // when
    let cacheId = sut.store(suggestion: suggestion, for: request)
    let beforeRemove = sut.get(for: request)
    #expect(beforeRemove != nil)

    sut.remove(cachedRequestId: cacheId)
    let afterRemove = sut.get(for: request)

    // then
    #expect(afterRemove == nil)
  }

  @Test("Remove with non-existent ID does not affect cache")
  func removeWithNonExistentIdDoesNotAffectCache() async throws {
    // given
    let sut = CompletionCache()
    let content = "func test() {}"
    let cursorPosition = Position(line: 0, character: 5)
    let file = URL(fileURLWithPath: "/test.swift")
    let workspace = URL(fileURLWithPath: "/workspace")

    let request = CompletionCacheRequest(
      workspace: workspace,
      file: file,
      content: content,
      selection: .init(start: cursorPosition, end: cursorPosition))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: " myFunc",
      cursor: cursorPosition))

    // when
    let cacheId = sut.store(suggestion: suggestion, for: request)
    sut.remove(cachedRequestId: 99999) // non-existent ID
    let result = sut.get(for: request)

    // then
    let retrieved = try #require(result)
    #expect(retrieved.cacheId == cacheId)
    #expect(retrieved.suggestion != nil)
  }

  @Test("Remove does not affect other cached entries")
  func removeDoesNotAffectOtherCachedEntries() async throws {
    // given
    let sut = CompletionCache()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file1 = URL(fileURLWithPath: "/test1.swift")
    let file2 = URL(fileURLWithPath: "/test2.swift")

    // First entry - multiline to make cache matching more reliable
    let content1 = """
      func test1() {
        // TODO
      }
      """
    let cursor1 = Position(line: 1, character: 2)
    let request1 = CompletionCacheRequest(
      workspace: workspace,
      file: file1,
      content: content1,
      selection: .init(start: cursor1, end: cursor1))
    let suggestion1 = try #require(createCompletion(
      oldContent: content1,
      completion: "  first()",
      cursor: cursor1,
      changeRange: .init(start: .init(line: 1, character: 0), end: .init(line: 1, character: 8))))

    // Second entry - multiline to make cache matching more reliable
    let content2 = """
      func test2() {
        // TODO
      }
      """
    let cursor2 = Position(line: 1, character: 2)
    let request2 = CompletionCacheRequest(
      workspace: workspace,
      file: file2,
      content: content2,
      selection: .init(start: cursor2, end: cursor2))
    let suggestion2 = try #require(createCompletion(
      oldContent: content2,
      completion: "  second()",
      cursor: cursor2,
      changeRange: .init(start: .init(line: 1, character: 0), end: .init(line: 1, character: 8))))

    // when
    let cacheId1 = sut.store(suggestion: suggestion1, for: request1)
    let cacheId2 = sut.store(suggestion: suggestion2, for: request2)

    sut.remove(cachedRequestId: cacheId1)

    let result1 = sut.get(for: request1)
    let result2 = sut.get(for: request2)

    // then
    #expect(result1 == nil)
    let retrieved2 = try #require(result2)
    #expect(retrieved2.cacheId == cacheId2)
    #expect(retrieved2.suggestion != nil)
  }

  @Test("Remove can be called multiple times with same ID")
  func removeCanBeCalledMultipleTimesWithSameId() async throws {
    // given
    let sut = CompletionCache()
    let content = "test"
    let cursor = Position(line: 0, character: content.count)
    let file = URL(fileURLWithPath: "/test.swift")
    let workspace = URL(fileURLWithPath: "/workspace")

    let request = CompletionCacheRequest(
      workspace: workspace,
      file: file,
      content: content,
      selection: .init(start: cursor, end: cursor))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: "ing",
      file: file,
      cursor: cursor))

    // when
    let cacheId = sut.store(suggestion: suggestion, for: request)
    sut.remove(cachedRequestId: cacheId)
    sut.remove(cachedRequestId: cacheId) // call again

    let result = sut.get(for: request)

    // then
    #expect(result == nil)
  }

  @Test("Remove works with nil suggestion entries")
  func removeWorksWithNilSuggestionEntries() async throws {
    // given
    let sut = CompletionCache()
    let content = "hello"
    let cursor = Position(line: 0, character: content.count)
    let file = URL(fileURLWithPath: "/test.swift")
    let workspace = URL(fileURLWithPath: "/workspace")

    let request = CompletionCacheRequest(
      workspace: workspace,
      file: file,
      content: content,
      selection: .init(start: cursor, end: cursor))

    // when - store nil suggestion
    let cacheId = sut.store(suggestion: nil, for: request)
    let beforeRemove = sut.get(for: request)
    #expect(beforeRemove != nil)

    sut.remove(cachedRequestId: cacheId)
    let afterRemove = sut.get(for: request)

    // then
    #expect(afterRemove == nil)
  }

  private func createCompletion(
    oldContent: String,
    completion: String,
    file: URL? = nil,
    cursor: Position,
    changeRange: Range? = nil)
    -> CompletionSuggestion?
  {
    let file = file ?? URL(fileURLWithPath: "/test.swift")
    let completion = RawCompletionSuggestion(
      file: file,
      startPosition: changeRange?.start ?? cursor,
      endPosition: changeRange?.end ?? cursor,
      completion: completion,
      id: UUID())

    return completion.applied(
      to: oldContent,
      file: file,
      selection: .init(start: cursor, end: cursor))
  }

  private func getInlineChanges(from old: String, to new: String) throws -> InlineDiff {
    let inline = try CompletionCacheTests.getChanges(from: old, to: new).inline
    return Array(inline)
  }

}

extension InlineDiff {
  var debugDescription: String {
    map(\.debugDescription).joined()
  }
}

extension Diff {
  var debugDescription: String {
    inline.debugDescription
  }
}
