// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - CodeCompletionProvidersPluginDependencyKey

public final class CodeCompletionProvidersPluginDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue = [any CodeCompletionProvider]()
  #else
  public static let testValue: [any CodeCompletionProvider] = [] as! [any CodeCompletionProvider]
  #endif
}

extension DependencyValues {
  public var codeCompletionProviders: [any CodeCompletionProvider] {
    get { self[CodeCompletionProvidersPluginDependencyKey.self] }
    set { self[CodeCompletionProvidersPluginDependencyKey.self] = newValue }
  }
}

// MARK: - CodeCompletionProvidersPluginProviding

public protocol CodeCompletionProvidersPluginProviding {
  var codeCompletionProviders: [any CodeCompletionProvider] { get }
}
