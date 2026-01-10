// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import ShellServiceInterface
import SwiftUI

// MARK: - ExecutableFinder

/// A helper that finds where a given executable is located on disk by running `which`.
@MainActor @Observable
final class ExecutableFinder {
  /// Initializes the finder and attempts to locate the executable using `which`.
  init(executable: String) {
    @Dependency(\.shellService) var shellService

    Task { [weak self] in
      do {
        let executablePath = try await shellService.runAndThrow("which \(executable)", useInteractiveShell: true)
        await MainActor.run {
          guard let self else { return }
          self.executablePath = executablePath?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      } catch {
        // Silently ignore errors - executable not found is expected
      }
    }
  }

  /// The path where the executable was found, or nil if not found.
  private(set) var executablePath: String?
}
