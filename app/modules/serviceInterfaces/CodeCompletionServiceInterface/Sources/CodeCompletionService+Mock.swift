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

  public var onSuggestCompletion: (@Sendable (CompletionRequest) async throws -> (
    cachedRequestId: Int,
    suggestion: CompletionSuggestion)?)?
  public var onCachedCompletion: (@Sendable (CompletionRequest) throws -> (
    cachedRequestId: Int,
    suggestion: CompletionSuggestion?)?)?
  public var onLogCompletionAcceptance: (@Sendable (CompletionSuggestion, Bool) -> Void)?

  public var _isAvailable: CurrentValueSubject<Bool, Never>

  public var isAvailable: ReadonlyCurrentValueSubject<Bool> {
    _isAvailable.readonly()
  }

  public func suggestCompletion(_ request: CompletionRequest)
    async throws -> (cachedRequestId: Int, suggestion: CompletionSuggestion)?
  {
    guard let onSuggestCompletion else {
      throw AppError("No completion provided")
    }
    return try await onSuggestCompletion(request)
  }

  public func cachedCompletion(_ request: CompletionRequest)
    throws -> (cachedRequestId: Int, suggestion: CompletionSuggestion?)?
  {
    guard let onCachedCompletion else {
      throw AppError("No completion provided")
    }
    return try onCachedCompletion(request)
  }

  public func deleteCachedCompletion(cachedRequestId _: Int) { }

  public func logCompletionAcceptance(suggestion: CompletionSuggestion, accepted: Bool) {
    onLogCompletionAcceptance?(suggestion, accepted)
  }
}
#endif
