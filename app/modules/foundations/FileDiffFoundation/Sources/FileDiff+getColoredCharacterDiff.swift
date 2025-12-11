// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import FileDiffTypesFoundation
import Foundation
import HighlightSwift
import XcodeThemeFoundation

// MARK: - FormattedCharacterDiff

/// Represents a set of character-level changes with syntax highlighting applied.
/// Used for code completion suggestions where changes need to be highlighted at the character level.
public struct FormattedCharacterDiff: Sendable {
  /// The line by line representation of the diff with character-level changes.
  public let lines: [FormattedCharacterDiffLine]

  public init(lines: [FormattedCharacterDiffLine]) {
    self.lines = lines
  }
}

// MARK: - FormattedCharacterDiffLine

/// Represents a single line in a character-level diff with syntax highlighting.
public struct FormattedCharacterDiffLine: Sendable {
  /// The full syntax-highlighted content for this line.
  public let content: AttributedString
  /// Character-level changes within this line, with their ranges in the attributed string.
  public let changes: [FormattedCharacterChange]

  public init(content: AttributedString, changes: [FormattedCharacterChange]) {
    self.content = content
    self.changes = changes
  }
}

// MARK: - FormattedCharacterChange

/// Represents a single character-level change within a line.
public struct FormattedCharacterChange: Sendable {
  /// The range of this change within the line's attributed string.
  public let range: Range<AttributedString.Index>
  /// The diff type for this change.
  public let type: DiffContentType

  public init(range: Range<AttributedString.Index>, type: DiffContentType) {
    self.range = range
    self.type = type
  }
}

// MARK: - FileDiff Extension

extension FileDiff {

  /// Creates a syntax-highlighted character-level diff suitable for code completion display.
  ///
  /// This method highlights the entire old and new content once, then extracts the relevant
  /// portions for each character-level change. This provides consistent syntax highlighting
  /// because the highlighter has full context.
  ///
  /// - Parameters:
  ///   - oldContent: The original content string
  ///   - newContent: The modified content string
  ///   - characterChanges: Array of lines, where each line contains character-level changes
  ///   - diffLineStart: The 0-based line index where the diff starts
  ///   - language: The language for syntax highlighting (default: swift)
  ///   - highlightColors: Color scheme to use for syntax highlighting
  /// - Returns: A `FormattedCharacterDiff` with syntax highlighting applied
  /// - Throws: May throw errors from the syntax highlighter
  public static func getColoredCharacterDiff(
    oldContent: String,
    newContent: String,
    characterChanges: [[CharacterLevelChange]],
    diffLineStart: Int,
    language: HighlightLanguage = .swift,
    highlightColors: HighlightColors)
    async throws -> FormattedCharacterDiff
  {
    // Highlight entire contents in parallel for best performance
    async let oldHighlightedTask = characterHighlighter.unTrimmedAttributedText(
      oldContent,
      language: language,
      colors: highlightColors)
    async let newHighlightedTask = characterHighlighter.unTrimmedAttributedText(
      newContent,
      language: language,
      colors: highlightColors)

    let oldHighlighted = try await oldHighlightedTask
    let newHighlighted = try await newHighlightedTask

    return buildFormattedDiff(
      oldContent: oldContent,
      newContent: newContent,
      oldHighlighted: oldHighlighted,
      newHighlighted: newHighlighted,
      characterChanges: characterChanges,
      diffLineStart: diffLineStart)
  }

  /// Creates a syntax-highlighted character-level diff using an XcodeTheme for colors.
  ///
  /// - Parameters:
  ///   - oldContent: The original content string
  ///   - newContent: The modified content string
  ///   - characterChanges: Array of lines, where each line contains character-level changes
  ///   - diffLineStart: The 0-based line index where the diff starts
  ///   - language: The language for syntax highlighting (default: swift)
  ///   - xcodeTheme: Optional Xcode theme to use for colors. If nil, uses default Xcode colors.
  ///   - styledOldContent: Optional pre-computed highlighted old content task (for caching across calls)
  ///   - styledNewContent: Optional pre-computed highlighted new content task (for caching across calls)
  /// - Returns: A `FormattedCharacterDiff` with syntax highlighting applied (foreground colors only, no background)
  /// - Throws: May throw errors from the syntax highlighter
  public static func getColoredCharacterDiff(
    oldContent: String,
    newContent: String,
    characterChanges: [[CharacterLevelChange]],
    diffLineStart: Int,
    language: HighlightLanguage = .swift,
    xcodeTheme: XcodeTheme?,
    styledOldContent: Task<AttributedString, Error>? = nil,
    styledNewContent: Task<AttributedString, Error>? = nil)
    async throws -> FormattedCharacterDiff
  {
    let highlightColors = highlightColors(from: xcodeTheme)

    // Use pre-computed highlighting if available, otherwise compute it
    let oldHighlighted: AttributedString
    let newHighlighted: AttributedString

    if let styledOldContent, let styledNewContent {
      // Use cached highlighting tasks
      oldHighlighted = try await styledOldContent.value
      newHighlighted = try await styledNewContent.value
    } else {
      // Compute highlighting in parallel
      async let oldHighlightedTask = characterHighlighter.unTrimmedAttributedText(
        oldContent,
        language: language,
        colors: highlightColors)
      async let newHighlightedTask = characterHighlighter.unTrimmedAttributedText(
        newContent,
        language: language,
        colors: highlightColors)

      oldHighlighted = try await oldHighlightedTask
      newHighlighted = try await newHighlightedTask
    }

    return buildFormattedDiff(
      oldContent: oldContent,
      newContent: newContent,
      oldHighlighted: oldHighlighted,
      newHighlighted: newHighlighted,
      characterChanges: characterChanges,
      diffLineStart: diffLineStart)
  }

  /// Creates highlighting tasks that can be cached and reused across multiple calls.
  ///
  /// - Parameters:
  ///   - content: The content string to highlight
  ///   - language: The language for syntax highlighting
  ///   - xcodeTheme: Optional Xcode theme to use for colors
  /// - Returns: A task that produces the highlighted AttributedString
  public static func createHighlightingTask(
    for content: String,
    language: HighlightLanguage = .swift,
    xcodeTheme: XcodeTheme?)
    -> Task<AttributedString, Error>
  {
    let colors = highlightColors(from: xcodeTheme)
    return Task {
      try await characterHighlighter.unTrimmedAttributedText(
        content,
        language: language,
        colors: colors)
    }
  }

  private static let characterHighlighter = Highlight()

  /// Builds the formatted diff from pre-highlighted content.
  private static func buildFormattedDiff(
    oldContent: String,
    newContent: String,
    oldHighlighted: AttributedString,
    newHighlighted: AttributedString,
    characterChanges: [[CharacterLevelChange]],
    diffLineStart: Int)
    -> FormattedCharacterDiff
  {
    // Compute line offsets for both contents
    let oldLines = oldContent.splitLines()
    let newLines = newContent.splitLines()
    let oldLineOffsets = computeLineOffsets(for: oldLines)
    let newLineOffsets = computeLineOffsets(for: newLines)

    // Initialize character positions at the start of the diff
    var oldCharPos = oldLineOffsets[safe: diffLineStart] ?? 0
    var newCharPos = newLineOffsets[safe: diffLineStart] ?? 0

    // Build highlighted lines by extracting from pre-highlighted content
    var formattedLines = [FormattedCharacterDiffLine]()

    for lineChanges in characterChanges {
      var lineContent = AttributedString()
      var formattedChanges = [FormattedCharacterChange]()

      for change in lineChanges {
        let changeLength = change.text.count

        // Determine source content and position based on change type
        let (source, startPos): (AttributedString, Int)
        switch change.type {
        case .removed:
          source = oldHighlighted
          startPos = oldCharPos

        case .added, .unchanged:
          source = newHighlighted
          startPos = newCharPos
        }

        // Extract attributed substring from the pre-highlighted content
        if let sourceRange = source.range(startPos..<(startPos + changeLength)) {
          let startIdx = lineContent.endIndex
          var extracted = AttributedString(source[sourceRange])
          // Remove any background color - we only want font and foreground color
          extracted.backgroundColor = nil
          lineContent.append(extracted)
          let endIdx = lineContent.endIndex

          formattedChanges.append(FormattedCharacterChange(
            range: startIdx..<endIdx,
            type: change.type))
        }

        // Advance positions based on change type
        if change.type != .added {
          oldCharPos += changeLength
        }
        if change.type != .removed {
          newCharPos += changeLength
        }
      }

      formattedLines.append(FormattedCharacterDiffLine(
        content: lineContent,
        changes: formattedChanges))
    }

    return FormattedCharacterDiff(lines: formattedLines)
  }

  /// Builds HighlightColors from an XcodeTheme, or returns default Xcode colors.
  private static func highlightColors(from theme: XcodeTheme?) -> HighlightColors {
    guard let theme else {
      // Use default Xcode colors based on appearance
      let isDarkMode = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return isDarkMode ? .dark(.xcode) : .light(.xcode)
    }

    // Build CSS from Xcode theme
    let css = theme.buildHighlightJSCSS()
    return .custom(css: css, background: "")
  }

  /// Computes the character offset for each line in the content.
  private static func computeLineOffsets(for lines: [String.SubSequence]) -> [Int] {
    var offsets = [Int]()
    offsets.reserveCapacity(lines.count + 1)
    var offset = 0
    for line in lines {
      offsets.append(offset)
      offset += line.count
    }
    offsets.append(offset)
    return offsets
  }

}
