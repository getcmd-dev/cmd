// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LoggingServiceInterface

// MARK: - CommandExecutionResult

public struct CommandExecutionResult: Equatable, Sendable, Encodable {
  public let exitCode: Int32
  public let stdout: String?
  public let stderr: String?
  public let mergedOutput: String?

  public init(exitCode: Int32, stdout: String? = nil, stderr: String? = nil, mergedOutput: String? = nil) {
    self.exitCode = exitCode
    self.stdout = stdout
    self.stderr = stderr
    self.mergedOutput = mergedOutput
  }
}

// MARK: - Execution

public protocol Execution: Sendable {
  func tearDown() async
  func terminate() throws
}

// MARK: - StandardInputWriter

public protocol StandardInputWriter: Sendable {
  func write(_ string: String) async throws
  func finish() async throws
}

// MARK: - AsyncStringSequence

public protocol AsyncStringSequence: Sendable { }
// MARK: - ShellService

public typealias SubprocessHandle = @Sendable (Execution, StandardInputWriter, AsyncStream<Data>, AsyncStream<Data>) -> Void

// MARK: - ShellService

public protocol ShellService: Sendable {
  // MARK: Public

  /// Executes a shell command with optional environment variable customization.
  ///
  /// - Parameters:
  ///   - command: The shell command to execute
  ///   - cwd: Working directory for command execution. If nil, uses the current directory.
  ///   - useInteractiveShell: When true, loads the full interactive shell environment (zsh profile, etc.)
  ///   - env: Additional environment variables to merge with the shell environment.
  ///          These variables override any existing variables with the same name.
  ///          When useInteractiveShell is true, these are merged with the interactive shell environment.
  ///          When useInteractiveShell is false, these are used as the entire environement and replace the inherited one.
  ///   - body: Optional handler for processing stdin/stdout/stderr streams during execution
  /// - Returns: The execution result containing exit code and output streams
  /// - Throws: Shell execution errors
  @discardableResult
  func run(
    _ command: String,
    cwd: String?,
    useInteractiveShell: Bool,
    env: [String: String]?,
    body: SubprocessHandle?)
    async throws -> CommandExecutionResult

  /// The loaded interactive shell environment variables (from zsh -il).
  /// This is populated asynchronously during service initialization.
  var env: [String: String] { get }
}

extension ShellService {

  /// Convenience method for executing a shell command without stream handling.
  /// See the main run method for detailed parameter documentation.
  @discardableResult
  public func run(
    _ command: String,
    cwd: String? = nil,
    useInteractiveShell: Bool = false,
    env: [String: String]? = nil)
    async throws -> CommandExecutionResult
  {
    try await run(command, cwd: cwd, useInteractiveShell: useInteractiveShell, env: env, body: nil)
  }

  /// Convenience method for executing a shell command and returning only stdout.
  /// See the main run method for detailed parameter documentation.
  /// - Returns: The stdout output as a string, or nil if no output was produced
  public func stdout(
    _ command: String,
    cwd: String? = nil,
    useInteractiveShell: Bool = false,
    env: [String: String]? = nil)
    async throws -> String?
  {
    let result = try await run(
      command,
      cwd: cwd,
      useInteractiveShell: useInteractiveShell,
      env: env,
      body: nil)
    return result.stdout
  }
}

// MARK: - ShellServiceProviding

public protocol ShellServiceProviding {
  var shellService: ShellService { get }
}
