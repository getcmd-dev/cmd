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
    Group {
        if let completion = viewModel.completion, let completionRequest = viewModel.completionTask?.request {
        CompletionDiffView(
          completion: completion,
          font: viewModel.font,
          lineSpacing: viewModel.lineSpacing)
          .padding(.top, viewModel.verticalContentOffset)
          .padding(.top, (viewModel.lineHeight ?? 0) * CGFloat(completion.diffLineStart - completionRequest.selection.start.line))
          .padding(.leading, viewModel.horizontalContentOffset)
      } else {
        // Empty state with minimal size
        Color.clear.frame(width: 1, height: 1)
      }
    }
    .fixedSize()
  }
}

// MARK: - CompletionDiffView

struct CompletionDiffView: View {
  let completion: CompletionSuggestion
  let font: NSFont
  let lineSpacing: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(completion.diff.indices, id: \.self) { index in
        view(for: completion.diff[index], lineIdx: index)
      }
    }
    .font(.init(font))
  }

  @ViewBuilder
  func view(for line: CompletionSuggestion.LineChange, lineIdx: Int) -> some View {
    HStack(spacing: 0) {
      ForEach(line.changes.indices, id: \.self) { index in
        let change = line.changes[index]
        Text(change.text.trimmingCharacters(in: .newlines))
          .lineSpacing(lineSpacing)
          .foregroundColor(color(for: change.type))
          .background(backgroundColor(for: change.type))
          .isHidden(isTextBeforeSuggestion(lineIdx: lineIdx, chunkIdx: index))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

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
    case .added: .green
    case .removed: .red
    case .unchanged: .primary
    }
  }

  private func backgroundColor(for type: FileDiffTypesFoundation.DiffContentType) -> Color {
    switch type {
    case .added: Color.green.opacity(0.2)
    case .removed: Color.red.opacity(0.2)
    case .unchanged: .clear
    }
  }
}
