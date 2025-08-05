// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ToolFoundation

public protocol ChatContextRegistryService: Sendable {
  func context(for threadId: String) throws -> any LiveToolExecutionContext
  func register(context: any LiveToolExecutionContext, for threadId: String)
}
