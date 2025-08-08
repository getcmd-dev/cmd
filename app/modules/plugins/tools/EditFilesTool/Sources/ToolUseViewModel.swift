// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodePreview
import Combine
import Dependencies
import FileDiffFoundation
import Foundation
import JSONFoundation
import Observation
import SwiftUI
import ToolFoundation
import XcodeControllerServiceInterface

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {
  /// - Parameters:
  ///   - status: The status of tool, which can be observed.
  ///   - input: The tool input.
  ///   - isInputComplete: Whether the tool has received all its input, or whether it is still streaming.
  ///   - updateToolStatus: a hook that allows to set the tool status.
  ///   - toolUseResult: The structured result containing information about changes.
  init(
    status: EditFilesTool.Use.Status,
    input: [EditFilesTool.Use.FileChange],
    isInputComplete: Bool,
    setResult: @escaping (EditFilesTool.Use.FormattedOutput) -> Void,
    toolUseResult: EditFilesTool.Use.FormattedOutput = .init(fileChanges: []))
  {
    self.status = status.value
    self.input = input
    self.isInputComplete = isInputComplete
    self.setResult = setResult
    self.toolUseResult = toolUseResult

    handleUpdatedInput()

    Task { [weak self] in
      for await status in status {
        self?.status = status
      }
    }
  }

  typealias Input = EditFilesTool.Use.Input

  var isInputComplete: Bool
  var status: ToolUseExecutionStatus<EditFilesTool.Output>

  @ObservationIgnored var toolUseResult: EditFilesTool.Use.FormattedOutput {
    didSet {
      setResult(toolUseResult)
    }
  }

  var input: [EditFilesTool.Use.FileChange] {
    didSet {
      handleUpdatedInput()
    }
  }

  var changes: [(path: URL, change: FileDiffViewModel, state: FileEditState)] {
    filesEdit.compactMap { file, state in
      guard let model = filesEditModels[file] else { return nil }
      return (file, model, state)
    }
  }

  /// Update the tool result status, acknowledging the suggestion received.
  func acknowledgeSuggestionReceived() {
    updateToolUseResult(status: .pending)
  }

  /// Apply the suggested change to one file and update the tool result status.
  @MainActor
  func applyChanges(to file: URL) async {
    do {
      try await modifyOneFile(file: file)
      updateToolUseResultForFile(file, status: .applied)
    } catch {
      updateToolUseResultForFile(file, status: .error(AppError(error)))
    }
  }

  /// Apply all the suggested change and update the tool result status.
  @MainActor
  func applyAllChanges() async {
    for fileChange in input {
      do {
        try await modifyOneFile(file: fileChange.path)
        updateToolUseResultForFile(fileChange.path, status: .applied)
      } catch {
        updateToolUseResultForFile(fileChange.path, status: .error(AppError(error)))
      }
    }
  }

  /// Undo the changes applied to one file, and update the tool status.
  @MainActor
  func undoChangesApplied(to file: URL) async {
    do {
      try await undoModificationToOneFile(file: file)
      updateToolUseResultForFile(file, status: .rejected)
    } catch {
      updateToolUseResultForFile(
        file,
        status: .error(AppError("Error rejecting changes for \(file.path): \(error.localizedDescription)")))
    }
  }

  /// Undo all the changes applied for this tool use, and update the tool status.
  @MainActor
  func undoAllAppliedChanges() async {
    for fileChange in input {
      do {
        try await undoModificationToOneFile(file: fileChange.path)
        updateToolUseResultForFile(fileChange.path, status: .rejected)
      } catch {
        updateToolUseResultForFile(
          fileChange.path,
          status: .error(AppError("Error rejecting changes for \(fileChange.path): \(error.localizedDescription)")))
      }
    }
  }

  func copyChanges(to file: URL) async {
    if let targetContent = await filesEditModels[file]?.targetContent {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(targetContent, forType: .string)
    }
  }

  @ObservationIgnored
  @Dependency(\.xcodeController) private var xcodeController

  private let setResult: (EditFilesTool.Use.FormattedOutput) -> Void
  private var filesEdit = [URL: FileEditState]()
  private var filesEditModels = [URL: FileDiffViewModel]()

  /// Update the tool use result with a new status for all files
  private func updateToolUseResult(status: EditFilesTool.Use.FileChangeStatus) {
    let updatedFileChanges = toolUseResult.fileChanges.map { fileChange in
      EditFilesTool.Use.FileChangeInfo(
        path: fileChange.path,
        isNewFile: fileChange.isNewFile,
        changeCount: fileChange.changeCount,
        status: status)
    }

    toolUseResult = EditFilesTool.Use.FormattedOutput(
      fileChanges: updatedFileChanges)
  }

  /// Update the tool use result for a specific file
  private func updateToolUseResultForFile(_ file: URL, status: EditFilesTool.Use.FileChangeStatus) {
    let updatedFileChanges = toolUseResult.fileChanges.map { fileChange in
      if fileChange.path == file.path {
        return EditFilesTool.Use.FileChangeInfo(
          path: fileChange.path,
          isNewFile: fileChange.isNewFile,
          changeCount: fileChange.changeCount,
          status: status)
      }
      return fileChange
    }

    toolUseResult = EditFilesTool.Use.FormattedOutput(
      fileChanges: updatedFileChanges)
  }

  /// As the input can be streamed, its value can change. Handle an update to the input.
  private func handleUpdatedInput() {
    // Ensure changes to each given file are grouped together, in case the LLM would not do this well.
    var changes = [URL: [EditFilesTool.Use.Input.FileChange.Change]]()
    var filesEdit = filesEdit
    for file in input {
      if var existingChanges = changes[file.path] {
        existingChanges.append(contentsOf: file.changes)
        changes[file.path] = existingChanges
      } else {
        changes[file.path] = file.changes
        filesEdit[file.path] = .suggested
      }
    }
    self.filesEdit = filesEdit

    // For each file,
    for (file, changes) in changes {
      updateChanges(for: file, changes: changes)
    }
  }

  /// As the input can be streamed, its value can change. Handle an update to the input for one file change.
  private func updateChanges(for file: URL, changes: [EditFilesTool.Use.Input.FileChange.Change]) {
    if let model = filesEditModels[file] {
      model.handle(newChanges: changes.map { .init(search: $0.search, replace: $0.replace) })
    } else {
      do {
        let model = try FileDiffViewModel(
          filePath: file.path,
          changes: changes.map {
            FileDiff.SearchReplace(search: $0.search, replace: $0.replace)
          },
          oldContent: input.first(where: { $0.path == file })?.baseLineContent)
        filesEditModels[file] = model
      } catch {
        if isInputComplete {
          updateToolUseResultForFile(file, status: .error(AppError(error)))
        } else {
          // The input data might be incorrect until we have received all the input. Ignore errors for now.
        }
      }
    }
  }

  /// Change one file according to the specified change.
  @MainActor
  private func modifyOneFile(file: URL) async throws {
    do {
      guard let diffViewModel = filesEditModels[file] else {
        // TODO: wait on view model to clear its diffing task queue.
        throw AppError("No changes available for file \(file.path)")
      }
      let baseLineContent = diffViewModel.baseLineContent
      let targetContent = await diffViewModel.targetContent
      let fileDiff = try FileDiff.getFileChange(changing: baseLineContent, to: targetContent)
      try await xcodeController.apply(fileChange: .init(
        filePath: file,
        oldContent: baseLineContent,
        suggestedNewContent: fileDiff.newContent,
        selectedChange: fileDiff.diff))
      filesEdit[file] = .applied
    } catch {
      filesEdit[file] = .error(error.localizedDescription)
      throw error
    }
  }

  /// Undo changes to one file.
  @MainActor
  private func undoModificationToOneFile(file: URL) async throws {
    do {
      guard let diffViewModel = filesEditModels[file] else {
        throw AppError("No changes available for file \(file.path)")
      }
      let baseLineContent = diffViewModel.baseLineContent
      let targetContent = await diffViewModel.targetContent
      let fileDiff = try FileDiff.getFileChange(changing: targetContent, to: baseLineContent)
      try await xcodeController.apply(fileChange: .init(
        filePath: file,
        oldContent: targetContent,
        suggestedNewContent: fileDiff.newContent,
        selectedChange: fileDiff.diff))
      filesEdit[file] = .rejected
    } catch {
      filesEdit[file] = .error(error.localizedDescription)
      throw error
    }
  }

}

// MARK: - FileEditState

enum FileEditState {
  case suggested
  case applied
  case rejected
  case error(String)
}
