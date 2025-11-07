// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionServiceInterface
import FileDiffTypesFoundation
import SwiftUI

// MARK: - CodeCompletionView

struct CodeCompletionView: View {
  @Bindable var viewModel: CodeCompletionViewModel
  var body: some View {
    Group {
      if let completion = viewModel.completion {
        CompletionDiffView(completion: completion)
          .padding(.top, viewModel.verticalContentOffset)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(completion.diff.indices, id: \.self) { index in
        view(for: completion.diff[index])
      }
    }
  }

  @ViewBuilder
  func view(for line: CompletionSuggestion.LineChange) -> some View {
    HStack(spacing: 0) {
      ForEach(line.changes.indices, id: \.self) { index in
        let change = line.changes[index]
        Text(change.text.trimmingCharacters(in: .newlines))
          .font(.system(.body, design: .monospaced))
          .foregroundColor(color(for: change.type))
          .background(backgroundColor(for: change.type))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
