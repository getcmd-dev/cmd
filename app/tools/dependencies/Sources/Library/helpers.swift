// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftParser
import SwiftSyntax

extension URL {
  public var canonicalURL: URL {
    var path = path.replacingOccurrences(of: "./", with: "")
    if !path.hasSuffix("/") {
      path += "/"
    }
    // Don't use absoluteURL as it resolves against the real filesystem
    // which doesn't work with mock file managers
    return URL(fileURLWithPath: path)
  }

  public func pathRelative(to reference: URL) -> String {
    var commonPathComponentsCount = 0
    for (a, b) in zip(self.pathComponents, reference.pathComponents) {
      if a != b {
        break
      } else {
        commonPathComponentsCount += 1
      }
    }

    let pathComponents = [String](repeating: "..", count: reference.pathComponents.count - commonPathComponentsCount)
      + pathComponents.dropFirst(commonPathComponentsCount)

    return pathComponents.joined(separator: "/")
  }
}

extension Array {

  public func uniqueSorted(by identifier: (Element) -> some Equatable & Comparable) -> [Element] {
    let sorted: [Element?] = sorted { identifier($0) < identifier($1) }
    return zip(sorted, [nil] + sorted)
      .filter { $0.0.map(identifier) != $0.1.map(identifier) }
      .compactMap(\.0)
  }

  mutating func uniqueSort(by identifier: (Element) -> some Equatable & Comparable) {
    self = uniqueSorted(by: identifier)
  }
}

/// Checks if a directory contains at least one file
func directoryIsNotEmpty(_ url: URL) -> Bool {
  guard
    let contents = fileManager.files(
      at: url,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles])
  else {
    return false
  }
  return !contents.isEmpty
}

extension String {
  public var camelCased: String {
    guard !isEmpty else { return "" }
    let parts = components(separatedBy: .alphanumerics.inverted)
    let first = parts.first!.lowercasingFirst
    let rest = parts.dropFirst().map(\.uppercasingFirst)

    return ([first] + rest).joined()
  }

  public func resolve(with base: String) -> String {
    let cleanPath = replacingOccurrences(of: "./", with: "")
    if cleanPath.hasPrefix("/") {
      return cleanPath
    }
    if base.hasSuffix("/") {
      return base + cleanPath
    }
    return base + "/" + cleanPath
  }

  private var lowercasingFirst: String { prefix(1).lowercased() + dropFirst() }
  private var uppercasingFirst: String { prefix(1).uppercased() + dropFirst() }

}

extension FileManagerI {
  /// Writes content to a file only if the AST differs, ignoring whitespace and comments.
  /// This is useful to avoid unnecessary file modifications.
  /// Those can have effects such as triggering linters or making Xcode re-resolve packages.
  func writeIfASTDiffers(_ content: String, to url: URL) throws {
    guard fileExists(atPath: url.path) else {
      try write(content, to: url, atomically: true, encoding: .utf8)
      return
    }
    let newContent = Syntax(Parser.parse(source: content))
    let existingContent = try read(contentsOfFile: url.path)
    let existingSource = Syntax(Parser.parse(source: existingContent))
    guard !astEqual(newContent, existingSource) else { return }
    try write(content, to: url, atomically: true, encoding: .utf8)
  }
}

/// Whether two syntax trees are equal, ignoring trivia (comments/whitespace).
func astEqual(_ a: Syntax, _ b: Syntax) -> Bool {
  // Node kinds must match
  guard a.kind == b.kind else { return false }

  // Tokens: compare token kinds (which include identifier/literal text),
  // but ignore trivia (comments/whitespace) by not looking at leading/trailingTrivia.
  if let ta = a.as(TokenSyntax.self), let tb = b.as(TokenSyntax.self) {
    return ta.tokenKind == tb.tokenKind
  }

  // Non-token nodes: compare children pairwise.
  // Use .sourceAccurate so we only consider present (non-missing) nodes/tokens.
  let ach = Array(a.children(viewMode: .sourceAccurate))
  let bch = Array(b.children(viewMode: .sourceAccurate))
  guard ach.count == bch.count else { return false }

  for (c1, c2) in zip(ach, bch) {
    if !astEqual(c1, c2) { return false }
  }
  return true
}

/// Calculates the Levenshtein distance between two strings.
/// This represents the minimum number of single-character edits (insertions, deletions, or substitutions)
/// required to change one string into another.
public func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
  let s1Array = Array(s1)
  let s2Array = Array(s2)
  let m = s1Array.count
  let n = s2Array.count

  guard m > 0 else { return n }
  guard n > 0 else { return m }

  var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

  for i in 0...m {
    dp[i][0] = i
  }
  for j in 0...n {
    dp[0][j] = j
  }

  for i in 1...m {
    for j in 1...n {
      if s1Array[i - 1] == s2Array[j - 1] {
        dp[i][j] = dp[i - 1][j - 1]
      } else {
        dp[i][j] = min(
          dp[i - 1][j] + 1, // deletion
          dp[i][j - 1] + 1, // insertion
          dp[i - 1][j - 1] + 1, // substitution
        )
      }
    }
  }

  return dp[m][n]
}
