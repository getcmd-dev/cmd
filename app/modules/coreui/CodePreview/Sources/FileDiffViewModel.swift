// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import ConcurrencyFoundation
import Dependencies
import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
import FoundationInterfaces
import HighlighterServiceInterface
import LoggingServiceInterface
import Observation
import XcodeControllerServiceInterface
import XcodeObserverServiceInterface

// MARK: - FileDiffViewModel

/// Represents a change that was suggested, and the relevant information about the changed file history.
@Observable @MainActor
public final class FileDiffViewModel: Sendable {

  public convenience init(
    filePath: String,
    llmDiff: String)
    throws
  {
    let fileContent: String
    do {
      @Dependency(\.xcodeObserver) var xcodeObserver
      fileContent = try xcodeObserver.getContent(of: URL(fileURLWithPath: filePath))
    } catch {
      // New file
      fileContent = ""
    }
    do {
      let changes = try FileDiff.parse(searchReplacePattern: llmDiff, for: fileContent)
      try self.init(filePath: filePath, changes: changes, oldContent: fileContent)
    } catch {
      defaultLogger.error("""
        Could not format diff for \(filePath): \(error)
        -- Diff:
        \(llmDiff)
        -- Current content:
        \(fileContent)
        --
        """)
      throw error
    }
  }

  public convenience init(
    filePath: String,
    changes: [FileDiff.SearchReplace],
    oldContent: String? = nil)
    throws
  {
    let path = URL(fileURLWithPath: filePath)
    let fileContent: String
    if let oldContent {
      fileContent = oldContent
    } else {
      do {
        @Dependency(\.xcodeObserver) var xcodeObserver
        fileContent = try xcodeObserver.getContent(of: path)
      } catch {
        // New file
        fileContent = ""
      }
    }

    do {
      let newContent = try FileDiff.apply(changes: changes, to: fileContent)
      if newContent == fileContent {
        throw AppError(
          message: "No change found",
          debugDescription: """
            No change found when changing \(filePath) with
            \(changes.map { ">>> search:\n\($0.search)\n=== replace:\n\($0.replace)\n<<<" }.joined(separator: "\n"))

            Current file content: \(fileContent)
            """)
      }

      let gitDiff = try FileDiff.getGitDiff(oldContent: fileContent, newContent: newContent)

      self.init(
        filePath: path,
        baseLineContent: fileContent,
        targetContent: newContent,
        canBeApplied: true,
        formattedDiff: nil)

      diffingTasks.queue {
        let formattedDiff = try await FileDiff.getColoredDiff(
          oldContent: fileContent,
          newContent: newContent,
          gitDiff: gitDiff,
          highlightColors: .codeHighlight)
        return .init(canBeApplied: true, formattedDiff: formattedDiff, baseLineContent: fileContent, targetContent: newContent)
      }
    } catch {
      defaultLogger.error("""
        Could not format diff for \(filePath): \(error)
        -- Changes:
        \(changes.map { "replace:\n\($0.search)\nwith:\n\($0.replace)" }.joined(separator: "\n-------\n"))
        -- Previous Content:
        \(fileContent)
        --
        """)
      throw error
    }
  }

  public init(
    filePath: URL,
    baseLineContent: String,
    targetContent: String,
    canBeApplied: Bool,
    formattedDiff: FormattedFileChange?)
  {
    self.filePath = filePath
    self.baseLineContent = baseLineContent
    _targetContent = targetContent
    self.canBeApplied = canBeApplied
    self.formattedDiff = formattedDiff

    @Dependency(\.xcodeObserver) var xcodeObserver
    @Dependency(\.xcodeController) var xcodeController

    self.xcodeObserver = xcodeObserver
    self.xcodeController = xcodeController

    cancellable = diffingTasks.sink { @Sendable newValue in
      Task { @MainActor [weak self] in
        guard let self, let newValue else { return }
        self.canBeApplied = newValue.canBeApplied
        self.formattedDiff = newValue.formattedDiff
        _targetContent = newValue.targetContent
      }
    }
  }

  /// The path to the file to change.
  public let filePath: URL
  /// The content of the file when the suggestion was made.
  public let baseLineContent: String

  /// Whether the suggestion can be applied at this time, given the current state of the file.
  public private(set) var canBeApplied: Bool
  /// A representation of the change in diff format with syntax highlighting.
  public private(set) var formattedDiff: FormattedFileChange?

  /// The content of the file if the suggestion was applied.
  public var targetContent: String {
    get async {
      await diffingTasks.waitForIdle()
      return _targetContent
    }
  }

  @MainActor
  public func handleApply(changes: [FormattedLineChange]) async throws {
    guard let formattedDiff else {
      throw AppError("Cannot apply changes before they has been prepared.")
    }
    let filePath = filePath
    let xcodeObserver = xcodeObserver
    let xcodeController = xcodeController

    // detach to avoid blocking the main actor, as for a long file this could take a bit.
    let task = Task.detached {
      // Try to get the content from the editor over the content from disk if possible.
      // TODO: look into doing this update _after_ the file has been made visible in Xcode.
      let editorContent = xcodeObserver.state.wrapped?.xcodesState.compactMap { xc in
        xc.workspaces.compactMap { ws in
          ws.tabs.compactMap { tab in
            tab.knownPath == filePath ? tab.lastKnownContent : nil
          }.first
        }.first
      }.first
      let currentContent = try editorContent ?? xcodeObserver.getContent(of: filePath)
      let targetContent = formattedDiff.changes.map(\.change).targetContent(applying: changes.map(\.change))

      let fileDiff = try FileDiff.getFileChange(changing: currentContent, to: targetContent)
      let fileChange = FileChange(
        filePath: filePath,
        oldContent: currentContent,
        suggestedNewContent: fileDiff.newContent,
        selectedChange: fileDiff.diff)
      try await xcodeController.apply(fileChange: fileChange)
    }
    try await task.value
  }

  @MainActor
  public func handleReject(changes: [FormattedLineChange]) throws {
    guard let formattedDiff else {
      throw AppError("Cannot reject changes before they has been prepared.")
    }
    let newDiff = formattedDiff.changes.suggestedContent(rejecting: changes)
    let newTargetContent = newDiff.map(\.change).targetContent

    _targetContent = newTargetContent
    self.formattedDiff = FormattedFileChange(changes: newDiff)
  }

  @MainActor
  public func handleApplyAllChange() async throws {
    guard let formattedDiff else {
      throw AppError("Cannot apply all changes before they has been prepared.")
    }
    try await handleApply(changes: formattedDiff.changes)
  }

//  @MainActor
//  public func handleReapplyChange() {
//    if
//      let updatedSuggestion = FileDiffViewModel(
//        filePath: filePath.path(),
//        changes: changes)
//    {
//      baseLineContent = updatedSuggestion.baseLineContent
//      gitDiff = updatedSuggestion.gitDiff
//      targetContent = updatedSuggestion.targetContent
//      canBeApplied = updatedSuggestion.canBeApplied
//      formattedDiff = updatedSuggestion.formattedDiff
//    }
//  }

  /// Handle an update received to the file changes. This can for instance happen when displaying changes that are being streamed and getting updated.
  public func handle(newChanges changes: [FileDiff.SearchReplace]) {
    let oldContent = baseLineContent
    diffingTasks.queue {
      let newContent = try FileDiff.apply(changes: changes, to: oldContent)

      let formatterDiff = try await FileDiff.getColoredDiff(
        oldContent: oldContent,
        newContent: newContent,
        highlightColors: .codeHighlight)

      return SuggestionUpdate(
        canBeApplied: true,
        formattedDiff: formatterDiff,
        baseLineContent: newContent,
        targetContent: newContent)
    }
  }

  private(set) var _targetContent: String

  private struct SuggestionUpdate: Sendable {
    /// Whether the suggestion can be applied at this time, given the current state of the file.
    public let canBeApplied: Bool
    /// A representation of the change in diff format with syntax highlighting.
    public let formattedDiff: FormattedFileChange
    /// The current content of the file.
    public let baseLineContent: String
    /// The content the file would have if the suggestion was applied.
    public let targetContent: String
  }

  private var cancellable: AnyCancellable?

  private let xcodeObserver: XcodeObserver
  private let xcodeController: XcodeController

  private let diffingTasks = ReplaceableTaskQueue<SuggestionUpdate?>()

}
