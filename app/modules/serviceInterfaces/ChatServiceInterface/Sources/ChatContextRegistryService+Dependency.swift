// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - ChatContextRegistryServiceProviding

public protocol ChatContextRegistryServiceProviding {
  var chatContextRegistry: ChatContextRegistryService { get }
}

// MARK: - ChatContextRegistryServiceDependencyKey

public final class ChatContextRegistryServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: ChatContextRegistryService = MockChatContextRegistryService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: ChatContextRegistryService = () as! ChatContextRegistryService
  #endif
}

extension DependencyValues {
  public var chatContextRegistry: ChatContextRegistryService {
    get { self[ChatContextRegistryServiceDependencyKey.self] }
    set { self[ChatContextRegistryServiceDependencyKey.self] = newValue }
  }
}
