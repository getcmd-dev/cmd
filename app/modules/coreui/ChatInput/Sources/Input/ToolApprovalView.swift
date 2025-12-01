// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import DLS
import SwiftUI
import ToolFoundation

// MARK: - ToolApprovalView

struct ToolApprovalView: View {

  let request: ToolApprovalRequest
  @Binding var suggestedResult: ToolApprovalResult
  let onApprovalResult: (ToolApprovalResult) -> Void

  var body: some View {
    VStack(alignment: .leading) {
      Text("**cmd** wants to use the tool *\(request.displayName)*")
        .frame(maxWidth: .infinity, alignment: .leading)
      VStack(spacing: 0) {
        option(for: .alwaysApprove, label: "Always Allow")
        option(for: .approved, label: "Allow Once")
        option(for: .denied, label: "Reject and describe what to do instead")
      }
    }
    .padding(12)
  }

  @ViewBuilder
  private func option(for result: ToolApprovalResult, label: String) -> some View {
    HoveredButton(
      action: {
        onApprovalResult(result)
      },
      onHoverColor: suggestedResult == result ? colorScheme.secondarySystemBackground : .clear,
      backgroundColor: suggestedResult == result ? colorScheme.secondarySystemBackground : .clear,

      padding: 5,
      onHover: { isHovered in
        if isHovered {
          suggestedResult = result
        }

      }) {
        HStack(spacing: 0) {
          if suggestedResult == result {
            Icon(systemName: "chevron.right")
              .padding(2)
              .frame(square: 15)
          } else {
            Spacer()
              .frame(square: 15)
          }

          Text(label)
          Spacer()
        }
      }
  }

  @Environment(\.colorScheme) private var colorScheme

}

// MARK: - Previews
#if DEBUG
@MainActor let suggestedApprovalResult = ObservableValue<ToolApprovalResult>(.alwaysApprove)

#Preview {
  ToolApprovalView(
    request: ToolApprovalRequest(
      toolName: "get_workspace_info",
      displayName: "Get Workspace Info"),
    suggestedResult: suggestedApprovalResult.binding,
    onApprovalResult: { _ in })
}
#endif
