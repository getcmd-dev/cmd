// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
import SharedValuesFoundation
import XcodeKit

// MARK: - ApplyEditCommand

final class ApplyEditCommand: CommandType, @unchecked Sendable {

  override var name: String { ExtensionCommandNames.applyEdit }

  override var timeoutAfter: TimeInterval { ExtensionTimeout.applyFileChangeTimeout }

  override func handle(_ invocation: XCSourceEditorCommandInvocation) async throws {
    let changeToApply: FileChange = try await LocalServer().send(
      command: ExtensionCommandKeys.getFileChangeToApply,
      input: EmptyInput())

    do {
      try SourceModificationHelpers.update(buffer: invocation.buffer, with: changeToApply)
      let _: EmptyResponse = try await LocalServer().send(
        command: ExtensionCommandKeys.confirmFileChangeApplied,
        input: FileChangeConfirmation(id: changeToApply.id, error: nil))
    } catch {
      let _: EmptyResponse = try await LocalServer().send(
        command: ExtensionCommandKeys.confirmFileChangeApplied,
        input: FileChangeConfirmation(id: changeToApply.id, error: error.nonEmptyDebugDescription ?? error.localizedDescription))
      // Rethrow for the error to be displayed in Xcode.
      throw error
    }
  }

}

extension Error {
  var nonEmptyDebugDescription: String? {
    let debugDescription = (self as CustomDebugStringConvertible).debugDescription
    if debugDescription.isEmpty {
      return nil
    }
    return debugDescription
  }
}
