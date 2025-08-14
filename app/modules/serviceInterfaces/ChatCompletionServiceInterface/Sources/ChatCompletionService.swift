// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// MARK: - ChatCompletionService

/// The `ChatCompletionService` supports a chat completion API compatible with OpenAI's API specs that allows for external applications
/// to use `cmd` as their AI backend. Most notably this can be used by the AI assistant in Xcode 26.
public protocol ChatCompletionService: Sendable {
  /// Start the HTTP server that handles the Chat completion API.
  func start()
}
