// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import Foundation
import ThreadSafe

#if DEBUG

@ThreadSafe
public final class MockCodeCompletionProvider: CodeCompletionProvider {
  public init(id: String = "mock-code-completion-provider") {
    self.id = id
  }

  public let id: String

  public var onProvideCompletion: (@Sendable () async throws -> CompletionSuggestion)?
  public var onDidSave: (@Sendable (URL, String) -> Void)?

  public func provideCompletion() async throws -> CompletionSuggestion {
    guard let onProvideCompletion else {
      throw AppError("No completion provided")
    }
    return try await onProvideCompletion()
  }

  public func didSave(file: URL, content: String) {
    onDidSave?(file, content)
  }
}
#endif
