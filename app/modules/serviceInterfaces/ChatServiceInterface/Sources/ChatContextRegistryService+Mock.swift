// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import ThreadSafe
import ToolFoundation

#if DEBUG
@ThreadSafe
public final class MockChatContextRegistryService: ChatContextRegistryService {

  public init() { }

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
#endif
