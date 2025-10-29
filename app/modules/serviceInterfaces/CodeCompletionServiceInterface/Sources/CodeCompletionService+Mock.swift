// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import AppFoundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockCodeCompletionService: CodeCompletionService {

  public init() { }

  public var onProvideCompletion: (@Sendable (TimeInterval) async throws -> CompletionSuggestion)?
  public var onLogCompletionAcceptance: (@Sendable (CompletionSuggestion, Bool) -> Void)?

  public func provideCompletion(timeout: TimeInterval) async throws -> CompletionSuggestion {
    guard let onProvideCompletion = onProvideCompletion else {
      throw AppError("No completion provided")
    }
    return try await onProvideCompletion(timeout)
  }

  public func logCompletionAcceptance(suggestion: CompletionSuggestion, accepted: Bool) {
    onLogCompletionAcceptance?(suggestion, accepted)
  }
}
#endif
