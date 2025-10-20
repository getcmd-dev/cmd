// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import SwiftModule

@Suite("Helpers Tests")
struct HelpersTests {

  @Test("Levenshtein distance - identical strings")
  func levenshteinDistanceIdentical() {
    #expect(levenshteinDistance("test", "test") == 0)
    #expect(levenshteinDistance("ClaudeCodeTool", "ClaudeCodeTool") == 0)
  }

  @Test("Levenshtein distance - one character difference")
  func levenshteinDistanceOneChar() {
    #expect(levenshteinDistance("test", "best") == 1)
    #expect(levenshteinDistance("ClaudeCodeTool", "ClaudeCodeTool1") == 1)
    #expect(levenshteinDistance("ClaudeCodeTool", "ClaudeCodeToo") == 1)
  }

  @Test("Levenshtein distance - two character difference")
  func levenshteinDistanceTwoChars() {
    #expect(levenshteinDistance("test", "best1") == 2)
    #expect(levenshteinDistance("ClaudeCodeTool", "ClaudeCodeTo1l") == 1) // one substitution: o->1
    #expect(levenshteinDistance("ClaudeCodeTool", "ClaudeCodePool") == 1) // one substitution: T->P
    #expect(levenshteinDistance("kitten", "sitting") == 3) // classic example: k->s, e->i, insert g
  }

  @Test("Levenshtein distance - completely different strings")
  func levenshteinDistanceDifferent() {
    #expect(levenshteinDistance("abc", "xyz") == 3)
    #expect(levenshteinDistance("short", "verylongstring") > 2)
  }

  @Test("Levenshtein distance - empty strings")
  func levenshteinDistanceEmpty() {
    #expect(levenshteinDistance("", "test") == 4)
    #expect(levenshteinDistance("test", "") == 4)
    #expect(levenshteinDistance("", "") == 0)
  }

  @Test("Levenshtein distance - case sensitivity")
  func levenshteinDistanceCaseSensitive() {
    #expect(levenshteinDistance("Test", "test") == 1)
    #expect(levenshteinDistance("CLAUDE", "claude") == 6)
  }
}
