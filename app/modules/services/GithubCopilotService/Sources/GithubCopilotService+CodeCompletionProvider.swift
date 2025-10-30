// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
import Foundation

extension DefaultGithubCopilotService {
  public var id: String {
    "github-copilot"
  }

  public func provideCompletion() async throws -> CompletionSuggestion {
    throw AppError("Not implemented")
  }

  public func didSave(file _: URL, content _: String) {
    // No-op
  }

}
