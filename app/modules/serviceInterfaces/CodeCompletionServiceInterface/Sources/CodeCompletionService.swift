// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import ConcurrencyFoundation
import FileDiffTypesFoundation
import Foundation
import XcodeObserverServiceInterface

// MARK: - CodeCompletionService

public protocol CodeCompletionService: Sendable {

  /// Whether the code completion service is available for use.
  var isAvailable: ReadonlyCurrentValueSubject<Bool> { get }
  /// Fetches a completion suggestion for the given file content and selection.
  func suggestCompletion(_ request: CompletionRequest)
    async throws -> (cachedRequestId: Int, suggestion: CompletionSuggestion)?

  /// Returns synchronously a cached completion suggestion if available.
  func cachedCompletion(_ request: CompletionRequest)
    throws -> (cachedRequestId: Int, suggestion: CompletionSuggestion?)?

  func deleteCachedCompletion(cachedRequestId: Int)

  /// Logs whether a suggested completion was accepted or rejected by the user.
  func logCompletionAcceptance(suggestion: CompletionSuggestion, accepted: Bool)
}

// MARK: - CompletionRequest

public struct CompletionRequest: Sendable {
  public let workspace: URL
  public let file: URL
  public let content: String
  public let selection: Selection
  public let timeout: TimeInterval

  public init(workspace: URL, file: URL, content: String, selection: Selection, timeout: TimeInterval) {
    self.workspace = workspace
    self.file = file
    self.content = content
    self.selection = selection
    self.timeout = timeout
  }
}
