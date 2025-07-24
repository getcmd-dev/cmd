// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import ThreadSafe

#if DEBUG
// MARK: - MockShellService

@ThreadSafe
public final class MockShellService: ShellService {

  public init() { }

  public var onRun: (
    @Sendable (String, String?, Bool, SubprocessHandle?) async throws
      -> CommandExecutionResult) = {
    _, _, _, _ in
    CommandExecutionResult(exitCode: 0)
  }

  public var env: [String: String] = [:]

  public func run(
    _ command: String,
    cwd: String?,
    useInteractiveShell: Bool,
    body: SubprocessHandle? = nil)
    async throws -> CommandExecutionResult
  {
    try await onRun(command, cwd, useInteractiveShell, body)
  }

}
#endif
