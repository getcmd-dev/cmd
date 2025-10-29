// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - CodeCompletionServiceDependencyKey

public final class CodeCompletionServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: CodeCompletionService = MockCodeCompletionService()
  #else
  public static let testValue: CodeCompletionService = () as! CodeCompletionService
  #endif
}

extension DependencyValues {
  public var codeCompletionService: CodeCompletionService {
    get { self[CodeCompletionServiceDependencyKey.self] }
    set { self[CodeCompletionServiceDependencyKey.self] = newValue }
  }
}

// MARK: - CodeCompletionServiceProviding

public protocol CodeCompletionServiceProviding {
  var codeCompletionService: CodeCompletionService { get }
}

