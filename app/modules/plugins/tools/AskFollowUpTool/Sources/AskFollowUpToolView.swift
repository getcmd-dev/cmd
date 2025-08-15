// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - AskFollowUpTool.Use + DisplayableToolUse

extension AskFollowUpTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    AnyToolUseViewModel(ToolUseViewModel(
      status: status,
      input: input,
      selectFollowUp: select(followUp:)))
  }
}

// MARK: - ToolUseView

struct ToolUseView: View {

  @Bindable var toolUse: ToolUseViewModel

  var body: some View {
    switch toolUse.status {
    case .notStarted:
      EmptyView()
    case .pendingApproval:
      pendingApprovalView
    case .approvalRejected:
      rejectedView
    case .running:
      followUpView(selection: nil)
    case .completed(.success(let output)):
      followUpView(selection: output.response)
    case .completed(.failure):
      EmptyView()
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  private var pendingApprovalView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Icon(systemName: "bubble.left.and.bubble.right")
          .frame(width: 14, height: 14)
          .foregroundColor(colorScheme.toolUseForeground)
        Text("Waiting for approval: Ask follow up question")
          .foregroundColor(colorScheme.toolUseForeground)
      }
      .padding(.vertical, 8)
    }
  }

  @ViewBuilder
  private var rejectedView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Icon(systemName: "bubble.left.and.bubble.right")
          .frame(width: 14, height: 14)
          .foregroundColor(colorScheme.toolUseForeground)
        Text("Rejected: Ask follow up question")
          .foregroundColor(colorScheme.toolUseForeground)
      }
      .padding(.vertical, 8)
    }
  }

  @ViewBuilder
  private func followUpView(selection: String?) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(toolUse.input.question)
        .textSelection(.enabled)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: false)
        .padding(.bottom, 8)
      ForEach(toolUse.input.followUp, id: \.self) { choice in
        HoveredButton(
          action: { toolUse.selectFollowUp(choice) },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: selection == choice ? colorScheme.tertiarySystemBackground : colorScheme.secondarySystemBackground,
          padding: 8,
          cornerRadius: 5,
          isEnable: selection == nil,
          disableClickThrough: true)
        {
          Text(choice)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .foregroundColor(foregroundColor(for: choice, with: selection))
        }.opacity(opacity(for: choice, with: selection))
      }
    }
  }

  private func foregroundColor(for choice: String, with selection: String?) -> Color {
    guard let selection else { return .primary }
    return selection == choice ? .primary : .secondary
  }

  private func opacity(for choice: String, with selection: String?) -> Double {
    guard let selection else { return 1 }
    return selection == choice ? 1 : 0.4
  }

}
