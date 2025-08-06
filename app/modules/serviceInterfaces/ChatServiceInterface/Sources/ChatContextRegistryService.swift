// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ToolFoundation

public protocol ChatContextRegistryService: Sendable {
  /// Returns the context associated with a give thread id.
  func context(for threadId: String) throws -> any LiveToolExecutionContext
  /// Register (and retain) the context associated with a given thread id.
  func register(context: any LiveToolExecutionContext, for threadId: String)
  /// Unregister (and release) the context associated with a given thread id.
  func unregister(threadId: String)
}
