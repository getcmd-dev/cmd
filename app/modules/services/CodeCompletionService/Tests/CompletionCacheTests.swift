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

    // MARK: - test {-some -}function{+ foo+}

    @Test
    func basic_acceptsExpectedVariants() throws {
      let diff = try getInlineChanges(from: "test some function", to: "test function foo")

      #expect("test some function".matches(diff)) // original
      #expect("test function foo".matches(diff)) // new
      #expect("test some function foo".matches(diff)) // original + added
      #expect("test function".matches(diff)) // original with deletion
      #expect("test function fo".matches(diff)) // subset of added chars
    }

    @Test
    func basic_rejectsInvalidVariants() throws {
      let diff = try getInlineChanges(from: "test some function", to: "test function foo")

      #expect("test some funcxtion".matches(diff) == false) // 'x' not in diff
      #expect("test foo function".matches(diff) == false) // wrong order
      #expect("est some function".matches(diff) == false) // missing required 't'
      #expect("".matches(diff) == false) // must contain unchanged test + function
      #expect("foo".matches(diff) == false) // only added, missing unchanged
    }

    // MARK: - test test {-foo-}{+test+} {-foo-}{+test+}

    @Test
    func chunkOrders_acceptsExpectedVariants() throws {
      let diff = try getInlineChanges(from: "test test foo foo", to: "test test test test")
      #expect("test test foo foo".matches(diff)) // original
      #expect("test test test test".matches(diff)) // new
      #expect("test test  ".matches(diff)) // original with deletion
      #expect("test test footest footest".matches(diff)) // original + added
    }

    @Test
    func chunkOrders_rejectsInvalidVariants() throws {
      let diff = try getInlineChanges(from: "test test foo foo", to: "test test test test")

      #expect("test ".matches(diff) == false) // breaks unchanged "test test "
      #expect("foo foo".matches(diff) == false) // only removed chars
      #expect("test test test foo".matches(diff)) // remove all but one "foo", adds none of the extra "test"
    }

    // MARK: - Unchanged suffix case (unchanged at the end)
    //
    // old: "bbaa"
    // new: "aabbaa"
    // Typical inline diff: [+ "aa" +][unchanged "bbaa"]
    // => any match must preserve "bbaa" as suffix.

    @Test
    func unchangedSuffix_mustBePreserved() throws {
      let diff = try getInlineChanges(from: "bbaa", to: "aabbaa")

      #expect("bbaa".matches(diff)) // skip added prefix
      #expect("aabbaa".matches(diff)) // full new string
      #expect("abbaa".matches(diff)) // adds first a only
      #expect("baa".matches(diff) == false) // missing part of unchanged
      #expect("aa".matches(diff) == false) // only added part, no unchanged
    }

    // MARK: - Simple added-then-unchanged case
    //
    // old: "a"
    // new: "aa"
    // Typical diff: [unchanged "a"][added "a"] or [added "a"][unchanged "a"]
    // Either way, "a" and "aa" should both be valid matches.

    @Test
    func addedThenUnchanged_oneA() throws {
      let diff = try getInlineChanges(from: "a", to: "aa")

      #expect("a".matches(diff)) // keep only the unchanged char
      #expect("aa".matches(diff)) // include added + unchanged
      #expect("".matches(diff) == false)
      #expect("b".matches(diff) == false)
    }

    // MARK: - Multiple unchanged blocks

    // old: "abcd"
    // new: "abXYcd"
    // Typical diff: [unchanged "ab"][added "XY"][unchanged "cd"]
    @Test
    func multipleUnchangedBlocks_mustAppearInOrder() throws {
      let diff = try getInlineChanges(from: "abcd", to: "abXYcd")

      // Valid:
      #expect("abcd".matches(diff)) // original
      #expect("abXYcd".matches(diff)) // new

      // Unchanged "ab" then "cd" must appear, in order:
      #expect("abdc".matches(diff) == false)
      #expect("cdab".matches(diff) == false)
      #expect("abXcd".matches(diff))
    }

    // MARK: - Only unchanged segments

    @Test
    func onlyUnchangedSegments() throws {
      let diff: InlineDiff = [.init(text: "hello", type: .unchanged)]

      #expect("hello".matches(diff)) // exact
      #expect("hell".matches(diff) == false) // missing char
      #expect("hello!".matches(diff) == false) // extra char not in diff
    }

    private func getInlineChanges(from old: String, to new: String) throws -> InlineDiff {
      try CompletionCacheTests.getChanges(from: old, to: new).inline
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

    let request = CompletionCacheRequest(
      file: file,
      content: content,
      selection: .init(start: cursorPosition, end: cursorPosition))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: "  print(0)",
      cursor: .init(line: 1, character: 2),
      changeRange: .init(start: .init(line: 1, character: 0), end: .init(line: 1, character: 20))))

    // when
    await sut.store(suggestion: suggestion, for: request)
    let result = await sut.get(for: request)

    // then
    let retrievedSuggestion = try #require(result)
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
      file: file,
      content: content,
      selection: .init(start: cursorPosition, end: cursorPosition))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: "  print(0)",
      cursor: .init(line: 1, character: 2),
      changeRange: .init(start: .init(line: 1, character: 0), end: .init(line: 1, character: 20))))

    // when
    await sut.store(suggestion: suggestion, for: request)
    let newCursorPosition = Position(line: 1, character: 4)
    let newRequest = CompletionCacheRequest(
      file: file,
      content: """
        func test() {
          pr
        }
        """,
      selection: .init(start: newCursorPosition, end: newCursorPosition))
    let result = await sut.get(for: newRequest)

    // then
    let retrievedSuggestion = try #require(result)
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
      file: file,
      content: content,
      selection: .init(start: cursor, end: cursor))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: " world",
      file: file,
      cursor: cursor))
    await sut.store(suggestion: suggestion, for: request)

    let outsideSelection = Position(line: 0, character: 0)
    let lookup = CompletionCacheRequest(
      file: file,
      content: content,
      selection: .init(start: outsideSelection, end: outsideSelection))

    let result = await sut.get(for: lookup)
    #expect(result == nil)
  }

  @Test("Cache keeps entries scoped per file URL")
  func cacheDoesNotMixFiles() async throws {
    let sut = CompletionCache()
    let content = "hello"
    let cursor = Position(line: 0, character: content.count)
    let selection = Range(start: cursor, end: cursor)

    let fileA = URL(fileURLWithPath: "/a.swift")
    let requestA = CompletionCacheRequest(file: fileA, content: content, selection: selection)
    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: " world",
      file: fileA,
      cursor: cursor))
    await sut.store(suggestion: suggestion, for: requestA)

    let fileB = URL(fileURLWithPath: "/b.swift")
    let requestB = CompletionCacheRequest(file: fileB, content: content, selection: selection)

    let result = await sut.get(for: requestB)
    #expect(result == nil)
  }

  @Test("Cache requires prefix match for lookup")
  func cacheRequiresMatchingPrefix() async throws {
    let sut = CompletionCache()
    let file = URL(fileURLWithPath: "/prefix.swift")
    let content = "hello"
    let cursor = Position(line: 0, character: content.count)
    let request = CompletionCacheRequest(
      file: file,
      content: content,
      selection: .init(start: cursor, end: cursor))

    let suggestion = try #require(createCompletion(
      oldContent: content,
      completion: " world",
      file: file,
      cursor: cursor))
    await sut.store(suggestion: suggestion, for: request)

    let mismatchedContent = "HELLO world"
    let mismatchCursor = Position(line: 0, character: mismatchedContent.count)
    let mismatchedRequest = CompletionCacheRequest(
      file: file,
      content: mismatchedContent,
      selection: .init(start: mismatchCursor, end: mismatchCursor))

    let result = await sut.get(for: mismatchedRequest)
    #expect(result == nil)
  }

  @Test("commonSuffix")
  func testCommonSuffix() {
    #expect("foo".commonSuffix(with: "boo") == "oo")
    #expect("foo".commonSuffix(with: "") == "")
    #expect("".commonSuffix(with: "boo") == "")
    #expect("foo!".commonSuffix(with: "boo") == "")
  }

  @Test("inline diff")
  func testInlineDiff() throws {
    #expect(try getInlineChanges(from: "print hello", to: "print hello\n world\n")
      .debugDescription == "print hello{+\n world\n+}")
  }

  private func createCompletion(
    oldContent: String,
    completion: String,
    file: URL? = nil,
    cursor: Position,
    changeRange: Range? = nil)
    -> AppliedCompletionSuggestion?
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
    try CompletionCacheTests.getChanges(from: old, to: new).inline
  }

}

extension InlineDiff {
  var debugDescription: String {
    map(\.debugDescription).joined()
  }
}
