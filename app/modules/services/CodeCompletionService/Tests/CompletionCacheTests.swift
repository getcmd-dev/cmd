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

    // MARK: - abc[-def-]gh{+ij+}  (old: "abcdefgh", new: "abcghij")

    @Test
    func abcDefGhIj_acceptsExpectedVariants() throws {
      let diff = try getInlineChanges(from: "abcdefgh", to: "abcghij")

      #expect("abcdefgh".matches(diff)) // original
      #expect("abcghij".matches(diff)) // new
      #expect("abcdefghij".matches(diff)) // original + added
      #expect("abcgh".matches(diff)) // original with deletion
      #expect("abcdgh".matches(diff)) // subset of removed chars
    }

    @Test
    func abcDefGhIj_rejectsInvalidVariants() throws {
      let diff = try getInlineChanges(from: "abcdefgh", to: "abcghij")

      #expect("abxdgh".matches(diff) == false) // 'x' not in diff
      #expect("abgcdh".matches(diff) == false) // wrong order
      #expect("abch".matches(diff) == false) // missing required 'g'
      #expect("".matches(diff) == false) // must contain unchanged abc + gh
      #expect("ij".matches(diff) == false) // only added, missing unchanged
    }

    // MARK: - aaa[-bbb-][+aaa+]  (old: "aaabbb", new: "aaaaaa")

    @Test
    func aaaBbbAaa_acceptsExpectedVariants() throws {
      let diff = try getInlineChanges(from: "aaabbb", to: "aaaaaa")

      #expect("aaabbb".matches(diff)) // original
      #expect("aaaaaa".matches(diff)) // new
      #expect("aaa".matches(diff)) // original with deletion
      #expect("aaabbbaaa".matches(diff)) // original + added
    }

    @Test
    func aaaBbbAaa_rejectsInvalidVariants() throws {
      let diff = try getInlineChanges(from: "aaabbb", to: "aaaaaa")

      #expect("aabbaa".matches(diff) == false) // breaks unchanged "aaa"
      #expect("a".matches(diff) == false) // missing required "aaa"
      #expect("bbbbbb".matches(diff) == false) // only removed chars
      #expect("aaab".matches(diff)) // remove all but one "b", adds none of the extra "a"
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

  ///
  ///  // MARK: - Basic Cache Operations
  ///
  @Test("Cache stores and retrieves exact match")
  func cacheStoresAndRetrievesExactMatch() async throws {
    // given
    let sut = await CompletionCache()
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
    #expect(retrievedSuggestion.diff.debugDescription == "  {-// TODO: im-}p{-leme-}{+ri+}nt{+(0)+}}")
    #expect(retrievedSuggestion.file == file)
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
