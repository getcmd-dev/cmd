// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockCodeCompletionService: CodeCompletionService {

  public init(isAvailable: Bool = false) {
    _isAvailable = .init(isAvailable)
  }

  public var onSuggestCompletion: (@Sendable (URL, URL, String, Range, TimeInterval) async throws -> CompletionSuggestion?)?
  public var onLogCompletionAcceptance: (@Sendable (CompletionSuggestion, Bool) -> Void)?

  public var _isAvailable: CurrentValueSubject<Bool, Never>

  public var isAvailable: ReadonlyCurrentValueSubject<Bool> {
    _isAvailable.readonly()
  }

  public func suggestCompletion(
    workspace: URL,
    file: URL,
    content: String,
    selection: Range,
    timeout: TimeInterval)
    async throws -> CompletionSuggestion?
  {
    guard let onSuggestCompletion else {
      throw AppError("No completion provided")
    }
    return try await onSuggestCompletion(workspace, file, content, selection, timeout)
  }

  public func logCompletionAcceptance(suggestion: CompletionSuggestion, accepted: Bool) {
    onLogCompletionAcceptance?(suggestion, accepted)
  }
}
#endif
