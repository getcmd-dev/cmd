// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LoggingServiceInterface
import SharedValuesFoundation
import XcodeKit

final class ReloadSettingsCommand: CommandType, @unchecked Sendable {
  override var name: String { ExtensionCommandNames.reloadSettings }

  override var timeoutAfter: TimeInterval { 1 }

  override func handle(_: XCSourceEditorCommandInvocation) async throws {
    defaultLogger.log("ReloadSettingsCommand triggered - crashing extension to force reload")

    // Force crash the extension to trigger reload
    Task {
      try await Task.sleep(nanoseconds: 100_000_000)
      fatalError("Killing extension to reload settings")
    }
  }
}
