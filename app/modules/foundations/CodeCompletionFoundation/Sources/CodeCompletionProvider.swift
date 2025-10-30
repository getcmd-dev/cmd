// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CodeCompletionProvider

public protocol CodeCompletionProvider: Sendable {
  func provideCompletion() async throws -> CompletionSuggestion
  func didSave(file: URL, content: String)
  var id: String { get }
}

// MARK: - CodeCompletionProvidersPluginProviding

public protocol CodeCompletionProvidersPluginProviding {
  var codeCompletionProviders: [any CodeCompletionProvider] { get }
}
