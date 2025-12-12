// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionServiceInterface
import DLS
import FileDiffTypesFoundation
import SwiftUI
import XcodeThemeFoundation

// MARK: - CodeCompletionView

// TODO: if we don't plan on using the border highlight when expanding the completion, a good amount of this code can be simplified.

struct CodeCompletionView: View {
  @Bindable var viewModel: CodeCompletionViewModel

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        if let completion = viewModel.completion, let completionRequest = viewModel.completionTask?.request {
          if let screenshot = viewModel.screenshot, viewModel.isCompletionExpanded {
            VStack(alignment: .leading, spacing: 0) {
              Rectangle().frame(height: max(
                0,
                (viewModel.lineHeight ?? 0) *
                  CGFloat(completion.diffLineStart + completion.diff.count - completionRequest.selection.start.line - 1)))
                .foregroundColor(viewModel.xcodeBackgroundColor.map({ Color(nsColor: $0) }))
                .padding(.trailing, viewModel.trailingContentOffset)
                .padding(.leading, 10)

              Image(screenshot, scale: XcodeScreenshoter.retinaScale, label: Text(""))
            }
            .padding(.top, viewModel.lineHeight ?? 0)
            .padding(.top, viewModel.verticalContentOffset)
          }

          CompletionDiffView(
            completion: completion,
            styledCompletion: viewModel.styledCompletion,
            font: viewModel.font,
            lineHeight: viewModel.lineHeight,
            lineSpacing: viewModel.lineSpacing,
            backgroundColor: viewModel.xcodeBackgroundColor,
            currentLineBackgroundColor: viewModel.xcodeCurrentLineColor,
            xcodeTheme: viewModel.xcodeTheme,
            showCompletionExpansionInfo: !viewModel.isCompletionExpanded && viewModel.isCompletionExpandable)
            .padding(
              .top,
              (viewModel.lineHeight ?? 0) * CGFloat(completion.diffLineStart - completionRequest.selection.start.line))
            .padding(.leading, viewModel.leadingContentOffset + 1) // 1 to leave space for the cursor
            .padding(.trailing, viewModel.trailingContentOffset + 2) // 2 to not overlap with the scrollbar
            .frame(width: geometry.size.width)
            .fixedSize()
            .padding(.top, viewModel.verticalContentOffset)
        } else {
          // Empty state with minimal size
          Color.clear.frame(width: 1, height: 1)
        }

        if viewModel.showAutomaticCompletionStatusMessage {
          HStack(alignment: .bottom) {
            Spacer()
            VStack(alignment: .trailing) {
              Spacer()
              AutomaticCompletionStatusView(
                isEnabled: viewModel.isAutomaticCompletionEnabled)
            }
          }
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
      .clipped()
    }
  }
}

// MARK: - CompletionDiffView

struct CompletionDiffView: View {
  init(
    completion: CompletionSuggestion,
    styledCompletion: SyntaxHighlightedCompletion?,
    font: NSFont,
    lineHeight: CGFloat?,
    lineSpacing: CGFloat,
    backgroundColor: NSColor?,
    currentLineBackgroundColor: NSColor?,
    xcodeTheme: XcodeTheme?,
    showCompletionExpansionInfo: Bool)
  {
    self.completion = completion
    self.styledCompletion = styledCompletion
    self.font = font
    self.lineHeight = lineHeight
    self.lineSpacing = lineSpacing
    self.backgroundColor = backgroundColor ?? .clear
    self.currentLineBackgroundColor = currentLineBackgroundColor ?? .clear
    self.xcodeTheme = xcodeTheme
    self.showCompletionExpansionInfo = showCompletionExpansionInfo
  }

  let completion: CompletionSuggestion
  let styledCompletion: SyntaxHighlightedCompletion?
  let font: NSFont
  let lineHeight: CGFloat?
  let lineSpacing: CGFloat
  let backgroundColor: NSColor
  let currentLineBackgroundColor: NSColor
  let xcodeTheme: XcodeTheme?
  let showCompletionExpansionInfo: Bool

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(
          completion.diff.enumerated().filter { !showCompletionExpansionInfo || $0.offset == 0 },
          id: \.offset)
        { idx, lineCompletion in
          lineBackgroundView(for: lineCompletion, lineIdx: idx)
            .frame(height: lineHeight)
        }
      }
      .font(.init(font))

      if !showCompletionExpansionInfo {
        borderOverlay
      }

      VStack(alignment: .leading, spacing: 0) {
        ForEach(
          completion.diff.enumerated().filter { !showCompletionExpansionInfo || $0.offset == 0 },
          id: \.offset)
        { idx, lineCompletion in
          lineView(for: lineCompletion, lineIdx: idx, highlightedLine: styledCompletion?.lines[safe: idx])
            .frame(height: lineHeight)
        }
      }
      .font(.init(font))
      .onPreferenceChange(LinePrefixWidthPreferenceKey.self, perform: updatePrefixWidth)
      .onPreferenceChange(LineSuggestionWidthPreferenceKey.self, perform: updateSuggestionWidth)
    }
  }

  /// Represents the geometry of a single line's suggestion content.
  private struct LineGeometry: Equatable {
    let xOffset: CGFloat
    let width: CGFloat
  }

  private enum Constants {
    static let suggestedTextOpacity = 0.5
  }

  @Environment(\.colorScheme) private var colorScheme

  @State private var linePrefixWidths = [Int: CGFloat]()
  @State private var lineSuggestionWidths = [Int: CGFloat]()

  /// The border overlay that wraps the suggestion content.
  @ViewBuilder
  private var borderOverlay: some View {
    if let lineHeight, !lineGeometries.isEmpty {
//      let bottomPadding: CGFloat = 2
//      let topPadding: CGFloat = 2
      let borderColor = Color.clear
      let borderWidth: CGFloat = 1
      let borderCornerRadius: CGFloat = 4
      let leadingPadding: CGFloat = 2
      let trailingPadding: CGFloat = 4

      let shape = SuggestionBorderShape(
        lineGeometries: lineGeometries.map { geo in
          SuggestionBorderShape.LineGeometry(
            xOffset: geo.xOffset,
            width: geo.width)
        },
        lineHeight: lineHeight,
        cornerRadius: borderCornerRadius,
        leadingPadding: leadingPadding,
        trailingPadding: trailingPadding,
//        topPadding: topPadding,
//        bottomPadding: bottomPadding
      )

      shape
        .fill(Color(nsColor: currentLineBackgroundColor))
        .overlay(shape.stroke(borderColor, lineWidth: borderWidth))
    }
  }

  /// Computes the line geometries for the border shape.
  private var lineGeometries: [LineGeometry] {
    let lineCount = showCompletionExpansionInfo ? 1 : completion.diff.count
    return (0..<lineCount).compactMap { idx in
      let xOffset = linePrefixWidths[idx] ?? 0
      guard let width = lineSuggestionWidths[idx], width > 0 else {
        return nil
      }
      return LineGeometry(xOffset: xOffset, width: width)
    }
  }

  @ViewBuilder
  private func lineBackgroundView(
    for line: CompletionSuggestion.LineChange,
    lineIdx: Int)
    -> some View
  {
    HStack(spacing: 0) {
      // Invisible texts to reserve space for unchanged text before the suggestion
      // Also measure the prefix width for border positioning
      ForEach(line.changes.indices.filter({ isTextBeforeSuggestion(lineIdx: lineIdx, chunkIdx: $0) }), id: \.self) { index in
        let change = line.changes[index]
        Text(change.text.trimmingCharacters(in: .newlines))
          .lineSpacing(lineSpacing)
          .isHidden(true)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: true)
      }

      // Background for suggested text
      ZStack(alignment: .topLeading) {
        backgroundColor(for: .unchanged, lineIdx: lineIdx)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func lineView(
    for line: CompletionSuggestion.LineChange,
    lineIdx: Int,
    highlightedLine: SyntaxHighlightedCompletion.HighlightedLine?)
    -> some View
  {
    HStack(spacing: 0) {
      // Invisible texts to reserve space for unchanged text before the suggestion
      // Also measure the prefix width for border positioning
      ForEach(line.changes.indices.filter({ isTextBeforeSuggestion(lineIdx: lineIdx, chunkIdx: $0) }), id: \.self) { index in
        let change = line.changes[index]
        Text(change.text.trimmingCharacters(in: .newlines))
          .lineSpacing(lineSpacing)
          .isHidden(true)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: true)
          .background(
            GeometryReader { geo in
              Color.clear.preference(
                key: LinePrefixWidthPreferenceKey.self,
                value: [lineIdx: geo.size.width])
            })
      }

      // Suggested text
      ZStack(alignment: .topLeading) {
        HStack(spacing: 0) {
          HStack(spacing: 0) {
            suggestionContent(for: line, lineIdx: lineIdx, highlightedLine: highlightedLine)
          }
          .background(
            GeometryReader { geo in
              Color.clear.preference(
                key: LineSuggestionWidthPreferenceKey.self,
                value: [lineIdx: geo.size.width])
            })
          if lineIdx == 0, showCompletionExpansionInfo {
            Text("⌘ to expand")
              .frame(height: lineHeight)
              .padding(.horizontal, 3)
              .with(cornerRadius: 6, backgroundColor: colorScheme.xcodeSidebarBackground)
              .padding(.leading, 16)
          }
        }
        .frame(height: lineHeight)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Accumulates prefix widths from all lines.
  private func updatePrefixWidth(_ values: [Int: CGFloat]) {
    for (idx, width) in values {
      linePrefixWidths[idx] = width
    }
  }

  /// Accumulates suggestion widths from all lines.
  private func updateSuggestionWidth(_ values: [Int: CGFloat]) {
    for (idx, width) in values {
      lineSuggestionWidths[idx] = width
    }
  }

  /// Renders the suggestion content with optional syntax highlighting.
  /// Uses attributed string when available, otherwise falls back to plain text.
  @ViewBuilder
  private func suggestionContent(
    for line: CompletionSuggestion.LineChange,
    lineIdx: Int,
    highlightedLine: SyntaxHighlightedCompletion.HighlightedLine?)
    -> some View
  {
    ForEach(line.changes.indices.filter({ !isTextBeforeSuggestion(lineIdx: lineIdx, chunkIdx: $0) }), id: \.self) { index in
      let change = line.changes[index]

      if
        let highlightedLine,
        let styledText = extractHighlightedChange(
          changeIndex: index,
          highlightedLine: highlightedLine)
      {
        // Use syntax-highlighted text (without background - it's handled by the parent)
        Text(styledText)
          .opacity(change.type == .unchanged ? 1 : Constants.suggestedTextOpacity)
          .lineSpacing(lineSpacing)
          .background(change.type == .removed ? colorScheme.removedLineDiffBackground : .clear)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: true)
          .padding(.top, lineSpacing / 2)
      } else {
        // Fallback to plain text
        Text(change.text.trimmingCharacters(in: .newlines))
          .opacity(change.type == .unchanged ? 1 : Constants.suggestedTextOpacity)
          .lineSpacing(lineSpacing)
          .foregroundColor(color(for: change.type))
          .background(change.type == .removed ? colorScheme.removedLineDiffBackground : .clear)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: true)
          .padding(.top, lineSpacing / 2)
      }
    }
  }

  /// Extracts the highlighted attributed string for a specific change, applying diff styling.
  private func extractHighlightedChange(
    changeIndex: Int,
    highlightedLine: SyntaxHighlightedCompletion.HighlightedLine)
    -> AttributedString?
  {
    // Get the highlighted change at the computed index
    guard changeIndex < highlightedLine.changes.count else {
      return nil
    }

    let highlightedChange = highlightedLine.changes[changeIndex]
    var styledText = AttributedString(highlightedLine.content[highlightedChange.range])
    let fullRange = styledText.startIndex..<styledText.endIndex
    styledText[fullRange].backgroundColor = .clear

    return styledText.trimmingCharacters(in: .newlines)
  }

  /// Whether a given chunk of change, at a given line in the suggestion is before any suggested content.
  private func isTextBeforeSuggestion(lineIdx: Int, chunkIdx: Int) -> Bool {
    if lineIdx > 0 {
      // The suggestion is trimmed to not have lines with no changes as suffix / prefix
      return false
    }
    for (idx, change) in completion.diff[lineIdx].changes.enumerated() {
      if change.type != .unchanged {
        return false
      }
      if idx == chunkIdx {
        return true
      }
    }
    return false
  }

  private func color(for type: FileDiffTypesFoundation.DiffContentType) -> Color {
    switch type {
    case .added: colorScheme.suggestedText
    case .removed: colorScheme.removedLineDiffText
    case .unchanged: colorScheme.suggestedText
    }
  }

  private func backgroundColor(for type: FileDiffTypesFoundation.DiffContentType, lineIdx: Int) -> Color {
    switch type {
    case .added: Color(nsColor: lineIdx == 0 ? currentLineBackgroundColor : backgroundColor)
    case .removed: colorScheme.removedLineDiffBackground
    case .unchanged: Color(nsColor: lineIdx == 0 ? currentLineBackgroundColor : backgroundColor)
    }
  }

}

// MARK: - AutomaticCompletionStatusView

struct AutomaticCompletionStatusView: View {
  let isEnabled: Bool

  var body: some View {
    HStack {
      Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundColor(isEnabled ? .green : .red)
      Text(isEnabled ? "Automatic Completion Enabled" : "Automatic Completion Disabled.\nTap ESC to trigger completion.")
        .foregroundColor(.primary)
    }
    .padding(8)
    .background(Color(.windowBackgroundColor).opacity(0.9))
    .cornerRadius(8)
    .padding()
  }
}

// MARK: - LinePrefixWidthPreferenceKey

/// Preference key to collect prefix widths for each line.
private struct LinePrefixWidthPreferenceKey: PreferenceKey {
  nonisolated(unsafe) static var defaultValue = [Int: CGFloat]()

  static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
    value.merge(nextValue()) { _, new in new }
  }
}

// MARK: - LineSuggestionWidthPreferenceKey

/// Preference key to collect suggestion content widths for each line.
private struct LineSuggestionWidthPreferenceKey: PreferenceKey {
  nonisolated(unsafe) static var defaultValue = [Int: CGFloat]()

  static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
    value.merge(nextValue()) { _, new in new }
  }
}
