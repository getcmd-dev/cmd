// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import ThreadSafe
import ToolFoundation

#if DEBUG
@ThreadSafe
public final class MockChatContextRegistryService: ChatContextRegistryService {

  public init(_ contexts: [String: any LiveToolExecutionContext] = [:]) {
    self.contexts = contexts
  }

  public var onContext: (@Sendable (String) throws -> any LiveToolExecutionContext)?

  public var onRegister: (@Sendable (any LiveToolExecutionContext, String) -> Void)?

  public var onUnregister: (@Sendable (String) -> Void)?

  public var contexts: [String: any LiveToolExecutionContext] = [:]

  public func context(for threadId: String) throws -> any LiveToolExecutionContext {
    if let onContext {
      return try onContext(threadId)
    }

    if let context = contexts[threadId] {
      return context
    } else {
      throw AppError("No context found for thread \(threadId)")
    }
  }

  public func register(context: any LiveToolExecutionContext, for threadId: String) {
    if let onRegister {
      onRegister(context, threadId)
    } else {
      contexts[threadId] = context
    }
  }

  public func unregister(threadId: String) {
    if let onUnregister {
      onUnregister(threadId)
    } else {
      contexts.removeValue(forKey: threadId)
    }
  }
}

@ThreadSafe
public final class MockChatThreadContext: LiveToolExecutionContext {

  public init(knownFilesContent: [String: String] = [:], userInfo: [String: any Codable & Sendable] = [:]) {
    self.knownFilesContent = knownFilesContent
    self.userInfo = userInfo
  }

  public func knownFileContent(for path: URL) -> String? {
    knownFilesContent[path.path]
  }

  public func set(knownFileContent: String, for path: URL) {
    knownFilesContent[path.path] = knownFileContent
  }

  public func pluginState<T>(for key: String) -> T? where T: Decodable, T: Encodable, T: Sendable {
    if let decodedObject = userInfo[key] as? T {
      return decodedObject
    }
    return nil
  }

  public func set(pluginState value: some Decodable & Encodable & Sendable, for key: String) {
    userInfo[key] = value
  }

  public func requestPersistence() { }

  private(set) var knownFilesContent: [String: String]
  private(set) var userInfo: [String: any Codable & Sendable]

}
#endif
