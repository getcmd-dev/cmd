// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// MARK: - FileDiff

import AppKit
import FileDiffTypesFoundation
import Foundation
import HighlightSwift

// MARK: - FormattedFileChange

/// Represents a set of changes for one file in a diff like format.
public struct FormattedFileChange: Sendable {
  /// The line by line representation of the diff.
  public let changes: [FormattedLineChange]

  public init(changes: [FormattedLineChange]) {
    self.changes = changes
  }
}

// MARK: - FormattedLineChange

@dynamicMemberLookup
public struct FormattedLineChange: Sendable {
  public let formattedContent: AttributedString
  public let change: LineChange

  public subscript<T>(dynamicMember keyPath: KeyPath<AttributedString, T>) -> T {
    formattedContent[keyPath: keyPath]
  }

  public init(formattedContent: AttributedString, change: LineChange) {
    self.formattedContent = formattedContent
    self.change = change
  }

  public init(formattedContent: AttributedSubstring, change: LineChange) {
    self.formattedContent = AttributedString(formattedContent)
    self.change = change
  }
}

// MARK: - FileDiff

extension FileDiff {

  /// Returns a formatted `AttributedString` showing the differences between two strings with syntax highlighting
  /// and background colors for added and removed content.
  ///
  /// - Parameters:
  ///   - oldContent: The original content string
  ///   - newContent: The modified content string
  ///   - gitDiff: If provided, the already computed git diff (with the header removed, as provided by `.getGitDiff`).
  ///   - highlightColors: Color scheme to use for syntax highlighting
  /// - Returns: An `AttributedString` with syntax highlighting and diff highlighting applied
  /// - Throws: May throw errors from the syntax highlighter
  public static func getColoredDiff(
    oldContent: String,
    newContent: String,
    gitDiff: String? = nil,
    highlightColors: HighlightColors)
    async throws -> FormattedFileChange
  {
    let diff = try gitDiff ?? getGitDiff(oldContent: oldContent, newContent: newContent)

    let diffRanges = gitDiffToChangedRanges(oldContent: oldContent, newContent: newContent, diffText: diff)

    async let oldContentFormatting = try await highlighter.unTrimmedAttributedText(
      oldContent,
      language: .swift,
      colors: highlightColors)
    async let newContentFormatting = try await highlighter.unTrimmedAttributedText(
      newContent,
      language: .swift,
      colors: highlightColors)

    let newContentFormatted = try await newContentFormatting
    let oldContentFormatted = try await oldContentFormatting
    var formattedLineChanges = [FormattedLineChange]()

    for lineChange in diffRanges {
      let formattedContent = lineChange.type == .removed ? oldContentFormatted : newContentFormatted
      guard let range = formattedContent.range(lineChange.characterRange) else {
        continue
      }
      let line = formattedContent[range]
      formattedLineChanges.append(FormattedLineChange(formattedContent: line, change: lineChange))
    }

    return FormattedFileChange(
      changes: formattedLineChanges)
  }

  private static let highlighter = Highlight()

}

extension AttributedString {
  /// Returns a range for the current AttributedString.
  ///
  /// - Parameter range: A closed range of integer indices representing the desired substring bounds
  /// - Returns: An optional `AttributedSubstring` containing the requested range of characters,
  ///           or `nil` if the range is invalid (out of bounds or incorrectly ordered)
  func range(_ range: Range<Int>) -> Range<AttributedString.Index>? {
    guard 0 <= range.lowerBound, range.lowerBound <= range.upperBound, range.upperBound <= characters.count else {
      return nil
    }

    let startIndex = index(startIndex, offsetByCharacters: range.lowerBound)
    let endIndex = index(self.startIndex, offsetByCharacters: range.upperBound)

    return startIndex..<endIndex
  }

}

extension Highlight {
  /// Syntax highlight some text with a specific language.
  /// - Parameters:
  ///   - text: The plain text code to highlight.
  ///   - language: The supported language to use.
  ///   - colors: The highlight colors to use (default: .xcode/.light).
  /// - Throws: Either a HighlightError or an Error.
  /// - Returns: A syntax highlighted attributed string, preserving leading / trailing whitespaces (including new lines).
  func unTrimmedAttributedText(
    _ text: String,
    language: HighlightLanguage,
    colors: HighlightColors = .light(.xcode))
    async throws -> AttributedString
  {
    var attributedText = try await attributedText(text, language: language, colors: colors)
    let trimmedPrefix = text.prefix(while: { $0.isWhitespace })
    let trimmedSuffix = text.reversed().prefix(while: { $0.isWhitespace }).reversed()

    // Reconstruct the attributed text with the original whitespace
    if !trimmedPrefix.isEmpty {
      let prefixString = AttributedString(String(trimmedPrefix))
      attributedText = prefixString + attributedText
    }
    if !trimmedSuffix.isEmpty {
      let suffixString = AttributedString(String(trimmedSuffix))
      attributedText = attributedText + suffixString
    }
    return attributedText
  }
}
