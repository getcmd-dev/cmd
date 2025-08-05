// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatServiceInterface

import AppFoundation
import DependencyFoundation
import ThreadSafe
import ToolFoundation

// MARK: - DefaultChatContextRegistryService

@ThreadSafe
final class DefaultChatContextRegistryService: ChatContextRegistryService {
  init() { }

  func context(for threadId: String) throws -> any LiveToolExecutionContext {
    guard let context = contexts[threadId] else {
      throw AppError("Context not found for threadId: \(threadId)")
    }

    return context
  }

  func register(context: any LiveToolExecutionContext, for threadId: String) {
    contexts[threadId] = context
  }

  private var contexts: [String: any LiveToolExecutionContext] = [:]
}

extension BaseProviding {
  public var chatContextRegistry: ChatContextRegistryService {
    shared {
      DefaultChatContextRegistryService()
    }
  }
}
