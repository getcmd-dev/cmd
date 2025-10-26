// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodePreview
import Dependencies
import DLS
import FileDiffFoundation
import FileDiffTypesFoundation
import FileIcon
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation
import XcodeControllerServiceInterface

// MARK: - ToolUseView

struct ToolUseView: View {

  @Bindable var toolUse: EditFilesToolUseViewModel

  var body: some View {
    switch toolUse.status {
    case .notStarted:
      VStack { }

    case .pendingApproval:
      pendingApprovalView

    case .approvalRejected:
      rejectedView

    case .running, .completed(.success):
      VStack(spacing: 12) {
        toolUseChanges
      }

    case .completed(.failure(let error)):
      errorView(error)
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  @State private var isErrorViewHovered = false

  @Dependency(\.xcodeController) private var xcodeController

  private var toolUseChanges: some View {
    ForEach(toolUse.changes, id: \.path) { fileChange in
      FileChangeExpandablePill(
        change: fileChange.change,
        editState: fileChange.state,
        handleApply: { [weak toolUse] in await toolUse?.applyChanges(to: fileChange.path) },
        handleReject: { [weak toolUse] in await toolUse?.undoChangesApplied(to: fileChange.path) },
        handleCopy: { [weak toolUse] in await toolUse?.copyChanges(to: fileChange.path) },
        handleOpenFile: { file in
          do {
            try await xcodeController.open(file: file, line: nil, column: nil)
          } catch {
            print("Failed to open file: \(error)")
          }
        })
    }
  }

  private var pendingApprovalView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Icon(systemName: "pencil")
          .frame(width: 14, height: 14)
          .foregroundColor(colorScheme.toolUseForeground)
        Text("Waiting for approval: Edit files")
          .foregroundColor(colorScheme.toolUseForeground)
      }
      .padding(.vertical, 8)
      ScrollView {
        toolUseChanges
          .padding(.vertical)
      }
    }
  }

  private var rejectedView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Icon(systemName: "pencil")
          .frame(width: 14, height: 14)
          .foregroundColor(colorScheme.toolUseForeground)
        Text("Rejected: Edit files")
          .foregroundColor(colorScheme.toolUseForeground)
      }
      .padding(.vertical, 8)
    }
  }

  private func errorView(_ error: Error) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading) {
        HStack {
          Text("Error editing file")
            .textSelection(.enabled)
            .foregroundColor(colorScheme.redError)
          Spacer(minLength: 0)
        }
        if isErrorViewHovered {
          Text(error.localizedDescription)
            .textSelection(.enabled)
            .foregroundColor(colorScheme.secondaryForeground)
        }
      }
      .onHover { isErrorViewHovered = $0 }
    }
  }

}
