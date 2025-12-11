// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import CodeCompletionServiceInterface
import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
import HighlightSwift
import SwiftUI
import XcodeThemeFoundation

// MARK: - SyntaxHighlightedCompletion

/// Represents a code completion suggestion with syntax highlighting applied.
struct SyntaxHighlightedCompletion: Sendable {
  /// Syntax-highlighted lines of the completion, preserving the diff structure.
  let lines: [HighlightedLine]

  struct HighlightedLine: Sendable {
    /// The attributed string for the entire line with syntax highlighting.
    let content: AttributedString
    /// Character-level changes in the line, with their ranges in the attributed string.
    let changes: [HighlightedChange]
  }

  struct HighlightedChange: Sendable {
    /// The range of this change within the line's attributed string.
    let range: Range<AttributedString.Index>
    /// The diff type for this change.
    let type: DiffContentType
  }
}

// MARK: - CompletionSyntaxHighlighter

/// Applies syntax highlighting to code completion suggestions.
@MainActor
enum CompletionSyntaxHighlighter {

  /// Creates a syntax-highlighted completion from a completion suggestion.
  ///
  /// This method highlights the entire old and new content once, then extracts the relevant
  /// portions for each character-level change. This provides consistent syntax highlighting
  /// because the highlighter has full context.
  ///
  /// - Parameters:
  ///   - completion: The completion suggestion to highlight.
  ///   - xcodeTheme: Optional Xcode theme to use for colors. If nil, uses default highlight colors.
  /// - Returns: A syntax-highlighted completion, or nil if highlighting fails.
  static func highlight(
    _ completion: CompletionSuggestion,
    xcodeTheme: XcodeTheme?)
    async -> SyntaxHighlightedCompletion?
  {
    // Convert the diff to character-level changes format
    let characterChanges: [[CharacterLevelChange]] = completion.diff.map { lineChange in
      lineChange.changes.map { CharacterLevelChange(text: $0.text, type: $0.type) }
    }

    do {
      // Use the FileDiff helper which highlights entire contents and extracts substrings
      // Background colors are stripped - only foreground colors are included
      // If the completion has cached highlighting tasks, use them for better performance
      let formattedDiff = try await FileDiff.getColoredCharacterDiff(
        oldContent: completion.oldContent,
        newContent: completion.newContent,
        characterChanges: characterChanges,
        diffLineStart: completion.diffLineStart,
        language: language(for: completion.file),
        xcodeTheme: xcodeTheme,
        styledOldContent: completion.styledOldContent,
        styledNewContent: completion.styledNewContent)

      // Convert to SyntaxHighlightedCompletion format
      let highlightedLines = formattedDiff.lines.map { line in
        SyntaxHighlightedCompletion.HighlightedLine(
          content: line.content,
          changes: line.changes.map { change in
            SyntaxHighlightedCompletion.HighlightedChange(
              range: change.range,
              type: change.type)
          })
      }

      return SyntaxHighlightedCompletion(lines: highlightedLines)
    } catch {
      return nil
    }
  }

  /// Determines the highlight language based on file extension.
  private static func language(for file: URL) -> HighlightLanguage {
    let ext = file.pathExtension.lowercased()
    // Try to map common extensions to highlight.js language identifiers
    let languageId =
      switch ext {
      case "swift": "swift"
      case "m", "mm": "objectivec"
      case "c": "c"
      case "cpp", "cc", "cxx": "cpp"
      case "h", "hpp": "cpp"
      case "py": "python"
      case "js": "javascript"
      case "ts": "typescript"
      case "jsx": "javascript"
      case "tsx": "typescript"
      case "rb": "ruby"
      case "go": "go"
      case "rs": "rust"
      case "java": "java"
      case "kt": "kotlin"
      case "json": "json"
      case "yaml", "yml": "yaml"
      case "xml": "xml"
      case "html", "htm": "html"
      case "css": "css"
      case "sh", "bash", "zsh": "bash"
      case "sql": "sql"
      case "md", "markdown": "markdown"
      default: "swift"
      }
    return HighlightLanguage(rawValue: languageId) ?? .swift
  }
}
