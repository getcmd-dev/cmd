// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
import LoggingServiceInterface
import SharedValuesFoundation
import XcodeKit

// MARK: - CmdCommand

/// Unified command that handles all extension operations based on queued input from the host app.
final class CmdCommand: CommandType, @unchecked Sendable {

  override var name: String { ExtensionActionName.cmd.rawValue }

  override func timeout(_: XCSourceEditorCommandInvocation) -> TimeInterval {
    // We can't determine the exact operation type without async call to getQueuedInput,
    // so we use the maximum timeout needed for any operation type
    // This preserves the existing behavior where applyEdit uses ExtensionTimeout.applyFileChangeTimeout
    ExtensionTimeout.applyFileChangeTimeout
  }

  override func handle(_ invocation: XCSourceEditorCommandInvocation) async throws {
    do {
      // Step 1: Ask the host app for queued input
      let input: ExtensionInput = try await LocalServer().send(.getQueuedInput)

      // Step 2: Execute the appropriate action based on input type
      let result: ExtensionResult =
        switch input {
        case .applyEdit(let fileChange):
          handleApplyEdit(fileChange: fileChange, buffer: invocation.buffer)

        case .reloadSettings:
          handleReloadSettings()

        case .getFormattingMetadata:
          handleGetFormattingMetadata(buffer: invocation.buffer)

        case .error(let errorMessage):
          defaultLogger.error("Extension received error from host app: \(errorMessage)")
          throw XcodeExtensionError(message: errorMessage)
        }

      // Step 3: Send the result back to the host app
      let _: EmptyResponse = try await LocalServer().send(.sendResult(result))
    } catch {
      defaultLogger.error("Internal action failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Action Handlers

  private func handleApplyEdit(fileChange: FileChange, buffer: XCSourceTextBuffer) -> ExtensionResult {
    do {
      try SourceModificationHelpers.update(buffer: buffer, with: fileChange)
      return .applyEditResult(.success(()))
    } catch {
      defaultLogger.error("Failed to apply edit: \(error.localizedDescription)")
      let extensionError = ExtensionError(message: error.localizedDescription)
      return .applyEditResult(.failure(extensionError))
    }
  }

  private func handleReloadSettings() -> ExtensionResult {
    // Force crash the extension to trigger reload
    Task {
      try await Task.sleep(nanoseconds: 100_000_000)
      fatalError("Killing extension to reload settings")
    }
    return .reloadSettingsResult
  }

  private func handleGetFormattingMetadata(buffer: XCSourceTextBuffer) -> ExtensionResult {
    let metadata = FileFormattingMetadata(
      tabSize: buffer.tabWidth,
      indentSize: buffer.indentationWidth,
      usesTabsForIndentation: buffer.usesTabsForIndentation,
      uti: buffer.contentUTI)
    return .formattingMetadataResult(.success(metadata))
  }

}
