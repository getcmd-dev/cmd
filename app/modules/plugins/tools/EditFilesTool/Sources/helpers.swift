// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatServiceInterface
import Dependencies
import Foundation
import LoggingServiceInterface
import ToolFoundation
import XcodeObserverServiceInterface

typealias FileChange = EditFilesTool.Use.FileChange
typealias RawInput = EditFilesTool.Use.Input

extension ToolExecutionContext {
  /// Compute the processed input, using either the persisted input or the raw input.
  /// - Parameters:
  ///   - persistedInput: The persisted input, if available.
  ///   - rawInput: The raw input to process.
  ///   - validateFileContent: Whether to validate that the last known files content matches the current one.
  func mappedInput(
    persistedInput: [FileChange]?,
    rawInput: RawInput,
    validateFileContent: Bool = true)
    -> ([FileChange], Error?)
  {
    if let persistedInput {
      return (persistedInput, nil)
    } else {
      let mappedInput = rawInput
        .withPathsResolved(from: projectRoot)
      do {
        @Dependency(\.chatContextRegistry) var chatContextRegistry
        @Dependency(\.xcodeObserver) var xcodeObserver
        let mappedInput = try mappedInput.withBaselineContent(
          chatContext: { try chatContextRegistry.context(for: threadId) },
          xcodeObserver: validateFileContent ? xcodeObserver : nil)
        return (mappedInput, nil)
      } catch {
        return (mappedInput, error)
      }
    }
  }

  /// Update the tracked content of the files that have changed.
  func updateFilesContent(changes: [EditFilesTool.Use.FileChangeInfo], input: [FileChange]) {
    // Update tracked content for successfully applied files
    let changedFiles = changes
      .filter { fileChange in
        switch fileChange.status {
        case .applied:
          true
        default:
          false
        }
      }
      .compactMap { fileChange in
        input.first { $0.path.path == fileChange.path }
      }

    @Dependency(\.chatContextRegistry) var chatContextRegistry
    @Dependency(\.xcodeObserver) var xcodeObserver
    for fileChange in changedFiles {
      do {
        let newContent = try xcodeObserver.getContent(of: fileChange.path)
        try chatContextRegistry.context(for: threadId).set(knownFileContent: newContent, for: fileChange.path)
      } catch {
        defaultLogger.error("Failed to update known content for \(fileChange.path.path): \(error)")
      }
    }
  }
}

extension RawInput {
  /// Ensure all path values are abosolute paths, resolving them from the given root URL if needed.
  func withPathsResolved(from root: URL?) -> [EditFilesTool.Use.FileChange] {
    files.map { fileChange in
      EditFilesTool.Use.FileChange(
        path: fileChange.path.resolvePath(from: root),
        isNewFile: fileChange.isNewFile,
        changes: fileChange.changes,
        baseLineContent: nil)
    }
  }

}

extension [FileChange] {

  /// Load and validate the baseline content for each modified file.
  /// - Parameters:
  ///   - chatContext: The chat context to use for loading the last known content of the files.
  ///   - xcodeObserver: Used to load the current content of the files. When `nil`, the content is not validated.
  func withBaselineContent(
    chatContext: () throws -> LiveToolExecutionContext,
    xcodeObserver: XcodeObserver?)
    throws -> Self
  {
    try map { fileChange in
      if fileChange.baseLineContent != nil {
        return fileChange
      }
      if fileChange.isNewFile == true {
        return EditFilesTool.Use.FileChange(
          path: fileChange.path,
          isNewFile: fileChange.isNewFile,
          changes: fileChange.changes,
          baseLineContent: "")
      }
      // The `LiveToolExecutionContext` should not be used during deserialization as the chat context has not yet been created.
      // This call is fine, since when deserializing the baseline content has been serialized and is not loaded from the chat context.
      guard let baseLineContent = try chatContext().knownFileContent(for: fileChange.path) else {
        throw AppError(
          "The file \(fileChange.path.path) has not been read yet. Make sure to first read any file you want to modify.")
      }
      if let xcodeObserver {
        guard try baseLineContent == xcodeObserver.getContent(of: fileChange.path) else {
          throw AppError(
            "The content of \(fileChange.path.path) has changed since it was last read. Re-read the relevant sections first.")
        }
      }

      return EditFilesTool.Use.FileChange(
        path: fileChange.path,
        isNewFile: fileChange.isNewFile,
        changes: fileChange.changes,
        baseLineContent: baseLineContent)
    }
  }

  func correcting(file: URL, with fixedInput: [EditFilesTool.Use.Input.FileChange.Change]) -> Self {
    var hasUpdatedFileChange = false
    return compactMap { fileChange in
      if fileChange.path.path == file.path {
        if hasUpdatedFileChange {
          // the corrected input is expected to contain a search/replace describing
          // all the file change at once. So we only keep one change to represent changes
          // to this file.
          return nil
        }
        hasUpdatedFileChange = true
        var change = fileChange
        change.correctedChanges = fixedInput
        return change
      }
      return fileChange
    }
  }

}

extension EditFilesTool.Use.FormattedOutput {
  var asToolUseResult: Result<EditFilesTool.Use.Output, Error> {
    let errors = fileChanges.compactMap { fileChange in
      if case .error(let error) = fileChange.status { return error }
      return nil
    }
    if !errors.isEmpty {
      return .failure(AppError(
        message: errors.map(\.message).joined(separator: "\n"),
        debugDescription: errors.map(\.debugDescription).joined(separator: "\n")))
    }
    let resultDescription = fileChanges.map { fileChange in
      switch fileChange.status {
      case .pending:
        "ℹ️ Pending: \(fileChange.path)"
      case .rejected:
        "rejected"
      case .applied:
        "✅ Applied: \(fileChange.path)" // TODO: return a snippet of the changed lines.
      case .error:
        // This should not happen as already handled.
        "🔴 Error"
      }
    }
    return .success(resultDescription.joined(separator: "\n"))
  }
}
