// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DependencyFoundation
import JRPCServiceInterface

// MARK: - DefaultJRPCService

final class DefaultJRPCService: JRPCService {

  init() { }

  func createConnection(
    command: String,
    env: [String: String],
    pwd: String?,
    delimitation: STDIODelimitation)
    -> StdioConnection
  {
    DefaultStdioConnection(command: command, env: env, pwd: pwd, delimitation: delimitation)
  }
}

extension BaseProviding {
  public var jrpcService: JRPCService {
    shared {
      DefaultJRPCService()
    }
  }
}
