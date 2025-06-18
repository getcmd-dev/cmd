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
  init(
    status: EditFilesTool.Use.Status,
    input: EditFilesTool.Use.Input,
    isInputComplete: Bool,
    updateToolStatus: @escaping (ToolUseExecutionStatus<EditFilesTool.Output>) -> Void,
    syncBaselineContent: @escaping (String, String) -> Void)
  {
    self.status = status.value
    self.input = input
    self.isInputComplete = isInputComplete
    self.updateToolStatus = updateToolStatus
    self.syncBaselineContent = syncBaselineContent

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

  @ObservationIgnored var toolResults: [String: JSON.Value] = [:] {
    didSet {
      updateToolStatus(.completed(.success(.init(result: .object(toolResults)))))
    }
  }

  var input: EditFilesTool.Use.Input {
    didSet {
      handleUpdatedInput()
    }
  }

  var changes: [(path: URL, change: FileDiffViewModel, state: FileEditState)] {
    filesEdit.compactMap { file, state in
      guard let model = filesEditModels[file.path] else { return nil }
      return (file, model, state)
    }
  }

  /// Update the tool result status, acknowledging the suggestion received.
  func acknowledgeSuggestionReceived() {
    toolResults = input.files.reduce(into: [String: JSON.Value]()) { acc, fileChange in
      acc[fileChange.path] = "Changes suggested."
    }
  }

  /// Apply the suggested change to one file and update the tool result status.
  @MainActor
  func applyChanges(to file: URL) async {
    do {
      try await modifyOneFile(file: file)
      toolResults[file.path] = "Changes applied."
    } catch {
      toolResults[file.path] = .string("Error applying changes: \(error.localizedDescription)")
    }
  }

  /// Apply all the suggested change and update the tool result status.
  @MainActor
  func applyAllChanges() async {
    var results: [String: JSON.Value] = [:]

    for fileChange in input.files {
      do {
        try await modifyOneFile(file: URL(filePath: fileChange.path))
        results[fileChange.path] = "Changes applied."
      } catch {
        results[fileChange.path] = .string("Error applying changes: \(error.localizedDescription)")
      }
    }
    toolResults = results
  }

  /// Undo the changes applied to one file, and update the tool status.
  @MainActor
  func undoChangesApplied(to file: URL) async {
    do {
      try await undoModificationToOneFile(file: file)
      toolResults[file.path] = "Changes rejected."
    } catch {
      toolResults[file.path] = .string("Error rejecting changes: \(error.localizedDescription)")
    }
  }

  /// Undo all the changes applied for this tool use, and update the tool status.
  @MainActor
  func undoAllAppliedChanges() async {
    var results: [String: JSON.Value] = [:]

    for fileChange in input.files {
      do {
        try await undoModificationToOneFile(file: URL(filePath: fileChange.path))
        results[fileChange.path] = "Changes rejected."
      } catch {
        results[fileChange.path] = .string("Error rejecting changes: \(error.localizedDescription)")
      }
    }
    toolResults = results
  }

  func copyChanges(to file: URL) async {
    if let targetContent = await filesEditModels[file.path]?.targetContent {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(targetContent, forType: .string)
    }
  }

  private let syncBaselineContent: (String, String) -> Void

  @ObservationIgnored
  @Dependency(\.xcodeController) private var xcodeController

  private let updateToolStatus: (ToolUseExecutionStatus<EditFilesTool.Output>) -> Void
  private var filesEdit = [URL: FileEditState]()
  private var filesEditModels = [String: FileDiffViewModel]()

  /// As the input can be streamed, its value can change. Handle an update to the input.
  private func handleUpdatedInput() {
    // Ensure changes to each given file are grouped together, in case the LLM would not do this well.
    var changes = [String: [EditFilesTool.Use.Input.FileChange.Change]]()
    var filesEdit = filesEdit
    for file in input.files {
      if var existingChanges = changes[file.path] {
        existingChanges.append(contentsOf: file.changes)
        changes[file.path] = existingChanges
      } else {
        changes[file.path] = file.changes
        filesEdit[URL(fileURLWithPath: file.path)] = .suggested
      }
    }
    self.filesEdit = filesEdit

    // For each file,
    for (filePath, changes) in changes {
      updateChanges(for: URL(filePath: filePath), changes: changes)
    }
  }

  /// As the input can be streamed, its value can change. Handle an update to the input for one file change.
  private func updateChanges(for file: URL, changes: [EditFilesTool.Use.Input.FileChange.Change]) {
    if let model = filesEditModels[file.path] {
      model.handle(newChanges: changes.map { .init(search: $0.search, replace: $0.replace) })
    } else {
      if
        let model = FileDiffViewModel(
          filePath: file.path,
          changes: changes.map {
            FileDiff.SearchReplace(search: $0.search, replace: $0.replace)
          },
          oldContent: input.files.first(where: { $0.path == file.path })?.baseLineContent)
      {
        filesEditModels[file.path] = model
        syncBaselineContent(file.path, model.baseLineContent)
      }
    }
  }

  /// Change one file according to the specified change.
  @MainActor
  private func modifyOneFile(file: URL) async throws {
    do {
      guard let diffViewModel = filesEditModels[file.path] else {
        // TODO: wait on view model to clear its diffing task queue.
        throw AppError("No changes available for file \(file.path)")
      }
      let baseLineContent = diffViewModel.baseLineContent
      let targetContent = await diffViewModel.targetContent
      let fileDiff = try FileDiff.getFileChange(changing: baseLineContent, to: targetContent)
      try await xcodeController.apply(fileChange: FileChange(
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
      guard let diffViewModel = filesEditModels[file.path] else {
        throw AppError("No changes available for file \(file.path)")
      }
      let baseLineContent = diffViewModel.baseLineContent
      let targetContent = await diffViewModel.targetContent
      let fileDiff = try FileDiff.getFileChange(changing: targetContent, to: baseLineContent)
      try await xcodeController.apply(fileChange: FileChange(
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
