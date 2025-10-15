// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - FileSuggestionServiceDependencyKey

public final class FileSuggestionServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: FileSuggestionService = MockFileSuggestionService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: FileSuggestionService = () as! FileSuggestionService
  #endif
}

extension DependencyValues {
  public var fileSuggestionService: FileSuggestionService {
    get { self[FileSuggestionServiceDependencyKey.self] }
    set { self[FileSuggestionServiceDependencyKey.self] = newValue }
  }
}
