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
    @Sendable (String, String?, Bool, [String: String]?, SubprocessHandle?) async throws
      -> CommandExecutionResult) = {
    _, _, _, _, _ in
    CommandExecutionResult(exitCode: 0)
  }

  public var env = [String: String]()

  public var onRunAppleScript: (@Sendable (String) throws -> String?) = { _ in nil }

  public func run(
    _ command: String,
    cwd: String?,
    useInteractiveShell: Bool,
    env: [String: String]?,
    body: SubprocessHandle? = nil)
    async throws -> CommandExecutionResult
  {
    try await onRun(command, cwd, useInteractiveShell, env, body)
  }

  public func run(appleScript: String) throws -> String? {
    try onRunAppleScript(appleScript)
  }

}
#endif
