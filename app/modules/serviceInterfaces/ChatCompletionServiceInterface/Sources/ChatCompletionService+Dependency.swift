// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - ChatCompletionServiceProviding

public protocol ChatCompletionServiceProviding {
  var chatCompletionService: ChatCompletionService { get }
}

// MARK: - ChatCompletionServiceDependencyKey

public final class ChatCompletionServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: ChatCompletionService = MockChatCompletionService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: ChatCompletionService = () as! ChatCompletionService
  #endif
}

extension DependencyValues {
  public var chatCompletion: ChatCompletionService {
    get { self[ChatCompletionServiceDependencyKey.self] }
    set { self[ChatCompletionServiceDependencyKey.self] = newValue }
  }
}
