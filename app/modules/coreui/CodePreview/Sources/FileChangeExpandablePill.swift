// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import FileIcon
import SwiftUI

// MARK: - FileEditState

/// Represents the current state of a file edit operation.
public enum FileEditState: Sendable {
  case suggested
  case applied
  case rejected
  case error(String)
}

// MARK: - FileChangeExpandablePill

/// A collapsible view that displays file changes with diff preview and action buttons.
///
/// Displays a header showing file name, icon, and change statistics (additions/deletions).
/// When expanded, shows a code preview with the actual diff. Provides actions to apply,
/// reject, or copy changes.
public struct FileChangeExpandablePill: View {
  /// Creates a file change expandable pill.
  /// - Parameters:
  ///   - change: The file diff view model containing change information.
  ///   - editState: The current state of the file edit (suggested, applied, rejected, or error).
  ///   - startsExpanded: Whether the pill should start in an expanded state. Default is false.
  ///   - handleApply: Async handler called when the user applies the changes.
  ///   - handleReject: Async handler called when the user rejects the changes.
  ///   - handleCopy: Async handler called when the user copies the changes.
  ///   - handleOpenFile: Async handler called when the user opens the file.
  public init(
    change: FileDiffViewModel,
    editState: FileEditState,
    startsExpanded: Bool = false,
    handleApply: @escaping () async -> Void,
    handleReject: @escaping () async -> Void,
    handleCopy: @escaping () async -> Void,
    handleOpenFile: @escaping (URL) async -> Void)
  {
    self.change = change
    self.editState = editState
    self.handleApply = handleApply
    self.handleReject = handleReject
    self.handleCopy = handleCopy
    self.handleOpenFile = handleOpenFile
    _isExpanded = .init(initialValue: startsExpanded)
  }

  public var body: some View {
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
              .onHover { isHovering in
                if isHovering {
                  NSCursor.pointingHand.push()
                } else {
                  NSCursor.pop()
                }
              }
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
            .textSelection(.enabled)
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

  let change: FileDiffViewModel
  let editState: FileEditState
  let handleApply: () async -> Void
  let handleReject: () async -> Void
  let handleCopy: () async -> Void
  let handleOpenFile: (URL) async -> Void

  private enum Constants {
    static let cornerRadius: CGFloat = 5
    static let spinnerSize: CGFloat = 11
  }

  @State private var isExpanded: Bool
  @State private var isHovering = false
  @State private var isApplyingChanges = false
  @State private var isRejectingChanges = false

  @Environment(\.colorScheme) private var colorScheme

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
      await handleOpenFile(change.filePath)
    }
  }
}

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

#if DEBUG
/// Add initiallyExpanded parameter to FileChangeExpandablePill for preview purposes
extension FileChangeExpandablePill {
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
    handleCopy: @escaping () async -> Void = { },
    handleOpenFile: @escaping (URL) async -> Void = { _ in })
  {
    self.change = change
    self.editState = editState
    self.handleApply = handleApply
    self.handleReject = handleReject
    self.handleCopy = handleCopy
    self.handleOpenFile = handleOpenFile
    _isExpanded = State(initialValue: initiallyExpanded)
  }
}
#endif
