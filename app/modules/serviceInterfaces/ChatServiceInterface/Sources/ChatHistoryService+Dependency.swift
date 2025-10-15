// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - ChatHistoryServiceProviding

public protocol ChatHistoryServiceProviding {
  var chatHistoryService: ChatHistoryService { get }
}

// MARK: - ChatHistoryServiceDependencyKey

public final class ChatHistoryServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: ChatHistoryService = MockChatHistoryService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: ChatHistoryService = () as! ChatHistoryService
  #endif
}

extension DependencyValues {
  public var chatHistoryService: ChatHistoryService {
    get { self[ChatHistoryServiceDependencyKey.self] }
    set { self[ChatHistoryServiceDependencyKey.self] = newValue }
  }
}
