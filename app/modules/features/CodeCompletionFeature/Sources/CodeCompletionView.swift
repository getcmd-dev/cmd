// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionServiceInterface
import DLS
import FileDiffTypesFoundation
import SwiftUI

// MARK: - CodeCompletionView

struct CodeCompletionView: View {
  @Bindable var viewModel: CodeCompletionViewModel

  var body: some View {
    GeometryReader { geometry in
      Group {
        if let completion = viewModel.completion, let completionRequest = viewModel.completionTask?.request {
          ZStack(alignment: .topLeading) {
            if let screenshot = viewModel.screenshot {
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
            }

            CompletionDiffView(
              completion: completion,
              font: viewModel.font,
              lineHeight: viewModel.lineHeight,
              lineSpacing: viewModel.lineSpacing,
              backgroundColor: viewModel.xcodeBackgroundColor,
              currentLineBackgroundColor: viewModel.xcodeCurrentLineColor)
              .padding(
                .top,
                (viewModel.lineHeight ?? 0) * CGFloat(completion.diffLineStart - completionRequest.selection.start.line))
              .padding(.leading, viewModel.leadingContentOffset + 1) // 1 to leave space for the cursor
              .padding(.trailing, viewModel.trailingContentOffset + 2) // 2 to not overlap with the scrollbar
              .frame(width: geometry.size.width)
              .fixedSize()
          }
          .padding(.top, viewModel.verticalContentOffset)
        } else {
          // Empty state with minimal size
          Color.clear.frame(width: 1, height: 1)
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
    font: NSFont,
    lineHeight: CGFloat? = nil,
    lineSpacing: CGFloat,
    backgroundColor: NSColor? = nil,
    currentLineBackgroundColor: NSColor? = nil)
  {
    self.completion = completion
    self.font = font
    self.lineHeight = lineHeight
    self.lineSpacing = lineSpacing
    self.backgroundColor = backgroundColor ?? .clear
    self.currentLineBackgroundColor = currentLineBackgroundColor ?? .clear
  }

  let completion: CompletionSuggestion
  let font: NSFont
  let lineHeight: CGFloat?
  let lineSpacing: CGFloat
  let backgroundColor: NSColor
  let currentLineBackgroundColor: NSColor

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(completion.diff.indices, id: \.self) { index in
        view(for: completion.diff[index], lineIdx: index)
          .frame(height: lineHeight)
      }
    }
    .font(.init(font))
  }

  @ViewBuilder
  func view(for line: CompletionSuggestion.LineChange, lineIdx: Int) -> some View {
    HStack(spacing: 0) {
      // Invisible texts to reserve space for unchanged text before the suggestion
      ForEach(line.changes.indices.filter({ isTextBeforeSuggestion(lineIdx: lineIdx, chunkIdx: $0) }), id: \.self) { index in
        let change = line.changes[index]
        Text(change.text.trimmingCharacters(in: .newlines))
          .lineSpacing(lineSpacing)
          .isHidden(true)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: true)
      }

      // Suggested text, with background
      ZStack(alignment: .topLeading) {
        backgroundColor(for: .unchanged, lineIdx: lineIdx)
          .frame(maxWidth: .infinity)

        ForEach(line.changes.indices.filter({ !isTextBeforeSuggestion(lineIdx: lineIdx, chunkIdx: $0) }), id: \.self) { index in
          let change = line.changes[index]
          Text(change.text.trimmingCharacters(in: .newlines))
            .lineSpacing(lineSpacing)
            .foregroundColor(color(for: change.type))
            .background(backgroundColor(for: change.type, lineIdx: lineIdx))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @Environment(\.colorScheme) private var colorScheme

  /// Whether a given chunk of change, at a given line in the suggestion is before and suggested content.
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
