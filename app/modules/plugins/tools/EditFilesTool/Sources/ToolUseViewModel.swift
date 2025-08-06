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
  init(
    status: EditFilesTool.Use.Status,
    input: [EditFilesTool.Use.FileChange],
    isInputComplete: Bool,
    updateToolStatus: @escaping (ToolUseExecutionStatus<EditFilesTool.Output>) -> Void)
  {
    self.status = status.value
    self.input = input
    self.isInputComplete = isInputComplete
    self.updateToolStatus = updateToolStatus

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
    toolResults = input.reduce(into: [String: JSON.Value]()) { acc, fileChange in
      acc[fileChange.path.path] = "Changes suggested."
    }
  }

  /// Apply the suggested change to one file and update the tool result status.
  @MainActor
  func applyChanges(to file: URL) async {
    do {
      try await modifyOneFile(file: file)
      toolResults[file.path] = "Changes applied."
    } catch {
      updateToolStatus(.completed(.failure(AppError("Error applying changes to \(file.path): \(error.localizedDescription)"))))
    }
  }

  /// Apply all the suggested change and update the tool result status.
  @MainActor
  func applyAllChanges() async {
    var results: [String: JSON.Value] = [:]

    for fileChange in input {
      do {
        try await modifyOneFile(file: fileChange.path)
        results[fileChange.path.path] = "Changes applied."
      } catch {
        updateToolStatus(
          .completed(.failure(AppError("Error applying changes to \(fileChange.path): \(error.localizedDescription)"))))
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
      updateToolStatus(.completed(.failure(AppError("Error rejecting changes for \(file.path): \(error.localizedDescription)"))))
    }
  }

  /// Undo all the changes applied for this tool use, and update the tool status.
  @MainActor
  func undoAllAppliedChanges() async {
    var results: [String: JSON.Value] = [:]

    for fileChange in input {
      do {
        try await undoModificationToOneFile(file: fileChange.path)
        results[fileChange.path.path] = "Changes rejected."
      } catch {
        updateToolStatus(
          .completed(.failure(AppError("Error rejecting changes for \(fileChange.path): \(error.localizedDescription)"))))
      }
    }
    toolResults = results
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

  private let updateToolStatus: (ToolUseExecutionStatus<EditFilesTool.Output>) -> Void
  private var filesEdit = [URL: FileEditState]()
  private var filesEditModels = [URL: FileDiffViewModel]()

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
      if
        let model = FileDiffViewModel(
          filePath: file.path,
          changes: changes.map {
            FileDiff.SearchReplace(search: $0.search, replace: $0.replace)
          },
          oldContent: input.first(where: { $0.path == file })?.baseLineContent)
      {
        filesEditModels[file] = model
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
