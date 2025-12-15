// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import CodeCompletionFeature

struct StringSplitWordsTests {

  @Test("Split simple sentence")
  func splitSimpleSentence() {
    // given
    let input = "some sentence"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["some", " sentence"])
  }

  @Test("Split with multiple spaces")
  func splitWithMultipleSpaces() {
    // given
    let input = "private   func foo()"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["private", "   func", " foo()"])
  }

  @Test("Split single word")
  func splitSingleWord() {
    // given
    let input = "hello"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["hello"])
  }

  @Test("Split word with underscore")
  func splitWordWithUnderscore() {
    // given
    let input = "my_variable"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["my_variable"])
  }

  @Test("Split with numbers")
  func splitWithNumbers() {
    // given
    let input = "value123"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["value123"])
  }

  @Test("Split with punctuation")
  func splitWithPunctuation() {
    // given
    let input = "let arr = [1, 2, 3]"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["let", " arr", " =", " [1,", " 2,", " 3]"])
  }

  @Test("Split with quotes")
  func splitWithQuotes() {
    // given
    let input = "print(\"hello\")"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["print(\"hello\")"])
  }

  @Test("Split empty string")
  func splitEmptyString() {
    // given
    let input = ""

    // when
    let result = input.splitWords()

    // then
    #expect(result == [])
  }

  @Test("Split whitespace only")
  func splitWhitespaceOnly() {
    // given
    let input = "   "

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["   "])
  }

  @Test("Split leading whitespace")
  func splitLeadingWhitespace() {
    // given
    let input = "  hello"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["  hello"])
  }

  @Test("Split trailing whitespace")
  func splitTrailingWhitespace() {
    // given
    let input = "hello  "

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["hello", "  "])
  }

  @Test("Split complex Swift code")
  func splitComplexSwiftCode() {
    // given
    let input = "func test() { print(\"hello\") }"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["func", " test()", " {", " print(\"hello\")", " }"])
  }

  @Test("Split with tabs")
  func splitWithTabs() {
    // given
    let input = "hello\tworld"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["hello", "\tworld"])
  }

  @Test("Split with newlines")
  func splitWithNewlines() {
    // given
    let input = "hello\nworld"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["hello", "\nworld"])
  }

  @Test("Split with mixed whitespace")
  func splitWithMixedWhitespace() {
    // given
    let input = "hello \t\n world"

    // when
    let result = input.splitWords()

    // then
    #expect(result == ["hello", " \t\n world"])
  }
}
