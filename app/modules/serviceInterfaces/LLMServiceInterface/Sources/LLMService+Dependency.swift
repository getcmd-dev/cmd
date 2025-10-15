// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - LLMServiceDependencyKey

public final class LLMServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: LLMService = MockLLMService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: LLMService = () as! LLMService
  #endif
}

extension DependencyValues {
  public var llmService: LLMService {
    get { self[LLMServiceDependencyKey.self] }
    set { self[LLMServiceDependencyKey.self] = newValue }
  }
}

// MARK: - LLMServiceProviding

public protocol LLMServiceProviding {
  var llmService: LLMService { get }
}
