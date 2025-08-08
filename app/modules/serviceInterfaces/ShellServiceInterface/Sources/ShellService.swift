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

  @discardableResult
  func run(
    _ command: String,
    cwd: String?,
    useInteractiveShell: Bool,
    body: SubprocessHandle?)
    async throws -> CommandExecutionResult

  var env: [String: String] { get }
}

extension ShellService {

  @discardableResult
  public func run(
    _ command: String,
    cwd: String? = nil,
    useInteractiveShell: Bool = false)
    async throws -> CommandExecutionResult
  {
    try await run(command, cwd: cwd, useInteractiveShell: useInteractiveShell, body: nil)
  }

  public func stdout(_ command: String, cwd: String? = nil, useInteractiveShell: Bool = false) async throws -> String? {
    let result = try await run(
      command,
      cwd: cwd,
      useInteractiveShell: useInteractiveShell,
      body: nil)
    return result.stdout
  }
}

// MARK: - ShellServiceProviding

public protocol ShellServiceProviding {
  var shellService: ShellService { get }
}
