// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodePreview
import Dependencies
import DLS
import FileDiffFoundation
import FileDiffTypesFoundation
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

  private var toolUseChanges: some View {
    ForEach(toolUse.changes, id: \.path) { fileChange in
      FileChangeView(
        change: fileChange.change,
        editState: fileChange.state,
        handleApply: { [weak toolUse] in await toolUse?.applyChanges(to: fileChange.path) },
        handleReject: { [weak toolUse] in await toolUse?.undoChangesApplied(to: fileChange.path) },
        handleCopy: { [weak toolUse] in await toolUse?.copyChanges(to: fileChange.path) })
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
            .foregroundColor(colorScheme.redError)
          Spacer(minLength: 0)
        }
        if isErrorViewHovered {
          Text(error.localizedDescription)
            .foregroundColor(colorScheme.secondaryForeground)
        }
      }
      .onHover { isErrorViewHovered = $0 }
    }
  }

}

// MARK: - FileDiffViewModel Extensions

extension FileDiffViewModel {
  var filename: String {
    filePath.lastPathComponent
  }

  var additionCount: Int? {
    formattedDiff?.changes.filter { $0.change.type == .added }.count
  }

  var deletionCount: Int? {
    formattedDiff?.changes.filter { $0.change.type == .removed }.count
  }
}

// MARK: - FileChangeView

struct FileChangeView: View {
  let change: FileDiffViewModel
  let editState: FileEditState
  let handleApply: () async -> Void
  let handleReject: () async -> Void
  let handleCopy: () async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      // Tab-style header when collapsed
      Button(action: {
        isExpanded.toggle()
      }) {
        HStack(spacing: 8) {
          FileIcon(filePath: change.filePath)
            .frame(width: 16, height: 16)

          Button(action: {
            openFile()
          }) {
            Text(change.filename)
              .font(.system(size: 12))
              .foregroundColor(colorScheme.primaryForeground)
              .lineLimit(1)
              .truncationMode(.head)
          }
          .buttonStyle(PlainButtonStyle())
          .help("Open file")
          if let additionCount = change.additionCount, let deletionCount = change.deletionCount {
            // Addition/deletion counts
            HStack(spacing: 2) {
              Text("+\(additionCount)")
                .font(.system(size: 10))
                .foregroundColor(colorScheme.addedLineDiffText)

              Text("-\(deletionCount)")
                .font(.system(size: 10))
                .foregroundColor(colorScheme.removedLineDiffText)
            }
          }

          Spacer()

          // Action buttons (visible on hover)
          if isHovering {
            HStack(spacing: 12) {
              // Copy button
              IconButton(
                action: { copyChanges() },
                systemName: "doc.on.doc",
                cornerRadius: 0,
                withCheckMark: true)
                .frame(width: 10, height: 10)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .help("Copy changes")

              if !hasAppliedChanges {
                if isApplyingChanges {
                  ProgressView()
                    .controlSize(.small)
                    .frame(width: Constants.spinnerSize, height: Constants.spinnerSize)
                    .help("Applying changes")
                } else {
                  // Apply/Checkmark button
                  Button(action: { applyChanges() }) {
                    Image(systemName: "checkmark")
                      .foregroundColor(.secondary)
                      .font(.system(size: 10))
                  }
                  .buttonStyle(PlainButtonStyle())
                  .help("Apply changes")
                }
              } else if !hasRejectedChanges {
                if isRejectingChanges {
                  ProgressView()
                    .controlSize(.small)
                    .frame(width: Constants.spinnerSize, height: Constants.spinnerSize)
                    .help("Rejecting changes")
                } else {
                  // Reject/X button
                  Button(action: { rejectChanges() }) {
                    Image(systemName: "xmark")
                      .foregroundColor(.secondary)
                      .font(.system(size: 10))
                  }
                  .buttonStyle(PlainButtonStyle())
                  .help("Reject changes")
                }
              }
            }
          }

          if hasAppliedChanges {
            // Apply/Checkmark
            Image(systemName: "checkmark")
              .foregroundColor(colorScheme.addedLineDiffText)
              .font(.system(size: 10))
              .help("Changes applied")
          } else if hasRejectedChanges {
            // Reject/X button
            Image(systemName: "xmark")
              .foregroundColor(colorScheme.removedLineDiffText)
              .font(.system(size: 10))
              .help("Changes rejected")
          }
          if case .error = editState {
            Image(systemName: "exclamationmark.triangle")
              .foregroundColor(.orange)
              .font(.system(size: 10))
          }

          // Expand/collapse button (hidden but keeps the tap area)
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundColor(.secondary)
            .font(.system(size: 12))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovering ? colorScheme.secondarySystemBackground : colorScheme.tertiarySystemBackground)
        .cornerRadius(isExpanded ? 0 : Constants.cornerRadius)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
          isHovering = hovering
        }
      }
      .buttonStyle(PlainButtonStyle())

      // Main content - only shown when expanded
      if isExpanded {
        if case .error(let error) = editState {
          Text("error: \(error)")
        }

        CodePreview(
          fileChange: change,
          collapsedHeight: 250,
          expandedHeight: nil)
      }
    }
    .with(cornerRadius: Constants.cornerRadius, borderColor: colorScheme.textAreaBorderColor)
    .padding(.horizontal, 4)
  }

  private enum Constants {
    static let cornerRadius: CGFloat = 5
    static let spinnerSize: CGFloat = 11
  }

  @State private var isExpanded = false
  @State private var isHovering = false
  @State private var isApplyingChanges = false
  @State private var isRejectingChanges = false

  @Environment(\.colorScheme) private var colorScheme

  @Dependency(\.xcodeController) private var xcodeController

  private var hasAppliedChanges: Bool {
    if case .applied = editState { return true }
    return false
  }

  private var hasRejectedChanges: Bool {
    if case .rejected = editState { return true }
    return false
  }

  private func copyChanges() {
    Task {
      await handleCopy()
    }
  }

  private func applyChanges() {
    isApplyingChanges = true
    Task {
      await handleApply()
      isApplyingChanges = false
    }
  }

  private func rejectChanges() {
    isRejectingChanges = true
    Task {
      await handleApply()
      isRejectingChanges = false
    }
  }

  private func openFile() {
    Task {
      do {
        try await xcodeController.open(file: change.filePath, line: nil, column: nil)
      } catch {
        print("Failed to open file: \(error)")
      }
    }
  }
}

#if DEBUG
/// Add initiallyExpanded parameter to FileChangeView for preview purposes
extension FileChangeView {
  init(
    change: FileDiffViewModel,
    editState: FileEditState,
    initiallyExpanded: Bool = false,
    handleApply: @escaping () async -> Void = {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    },
    handleReject: @escaping () async -> Void = {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    },
    handleCopy: @escaping () async -> Void = { })
  {
    self.change = change
    self.editState = editState
    self.handleApply = handleApply
    self.handleReject = handleReject
    self.handleCopy = handleCopy
    _isExpanded = State(initialValue: initiallyExpanded)
  }
}
#endif
