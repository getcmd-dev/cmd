// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LocalServerServiceInterface

#if DEBUG
public final class MockChatCompletionService: ChatCompletionService {

  public init() { }

  public func start() { }

  public func register(delegate _: ChatCompletionServiceDelegate) { }
}
#endif
