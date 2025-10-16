// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - ChatServiceProviding

public protocol ChatServiceProviding {
  var chatService: ChatService { get }
}

// MARK: - ChatServiceDependencyKey

public final class ChatServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: ChatService = MockChatService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: ChatService = () as! ChatService
  #endif
}

extension DependencyValues {
  public var chatService: ChatService {
    get { self[ChatServiceDependencyKey.self] }
    set { self[ChatServiceDependencyKey.self] = newValue }
  }
}
