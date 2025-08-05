// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import ThreadSafe
import ToolFoundation

#if DEBUG
@ThreadSafe
public final class MockChatContextRegistryService: ChatContextRegistryService {

  public init() { }

  public var onContext: (@Sendable (String) throws -> any LiveToolExecutionContext)?

  public func context(for threadId: String) throws -> any LiveToolExecutionContext {
    if let onContext {
      return try onContext(threadId)
    }

    fatalError("MockChatContextRegistryService: onContext not set")
  }

  public func register(context _: any LiveToolExecutionContext, for _: String) {
    fatalError("Not implemented")
  }
}
#endif
