// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import ShellServiceInterface
import ThreadSafe
import ToolFoundation

// MARK: - ExecuteCommandTool

public final class ExecuteCommandTool: NonStreamableTool {
  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  @ThreadSafe
  public final class Use: NonStreamableToolUse, UpdatableToolUse, @unchecked Sendable {
    public init(
      callingTool: ExecuteCommandTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = Input(
        command: input.command,
        cwd: input.cwd.map { $0.resolvePath(from: context.projectRoot).path() },
        canModifySourceFiles: input.canModifySourceFiles,
        canModifyDerivedFiles: input.canModifyDerivedFiles)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .pendingApproval)
      if case .completed = stream.value { updateStatus.finish() }
      // If the tool was running when the app was terminated, we don't support resume execution so it's set to cancelled.
      if case .running = stream.value { updateStatus.complete(with: .failure(CancellationError())) }
      status = stream
      self.updateStatus = updateStatus

      let (stdout, setStdout) = Future<BroadcastedStream<Data>, Never>.make()
      stdoutStream = stdout
      setStdoutStream = { stream in setStdout(.success(stream)) }
      let (stderr, setStderr) = Future<BroadcastedStream<Data>, Never>.make()
      stderrStream = stderr
      setStderrStream = { stream in setStderr(.success(stream)) }
    }

    public typealias InternalState = EmptyObject

    public struct Input: Codable, Sendable {
      public let command: String
      public let cwd: String?
      public let canModifySourceFiles: Bool
      public let canModifyDerivedFiles: Bool
    }

    public struct Output: Codable, Sendable {
      public let output: String?
      public let exitCode: Int32
    }

    // TODO: add support for readonly uses of the terminal.
    public let isReadonly = false

    public let callingTool: ExecuteCommandTool
    public let toolUseId: String
    public let input: Input

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
      try? runningProcess?.terminate()
    }

    public func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)

      Task {
        do {
          let shellResult = try await shellService.run(
            input.command,
            cwd: input.cwd ?? context.projectRoot?.path(),
            useInteractiveShell: true)
          { execution, _, stdout, stderr in
            self.runningProcess = execution
            self.setStdoutStream(.init(replayStrategy: .replayAll, stdout))
            self.setStderrStream(.init(replayStrategy: .replayAll, stderr))
          }

          let output = Output(
            output: shellResult.mergedOutput?.trimmed(toNotExceed: truncationLimit),
            exitCode: shellResult.exitCode)
          if shellResult.exitCode == 0 {
            updateStatus.complete(with: .success(output))
          } else {
            try updateStatus
              .yield(
                .completed(
                  .failure(
                    AppError(
                      "The command \(commandWasManuallyInterrupted ? "was interrupted by the user. Wait for further instructions." : "failed").\n\(String(data: JSONEncoder.sortingKeys.encode(output), encoding: .utf8) ?? "")"))))
          }
        } catch {
          updateStatus.complete(with: .failure(error))
        }
        runningProcess = nil
      }
    }

    let stdoutStream: Future<BroadcastedStream<Data>, Never>
    let stderrStream: Future<BroadcastedStream<Data>, Never>

    let setStdoutStream: (BroadcastedStream<Data>) -> Void
    let setStderrStream: (BroadcastedStream<Data>) -> Void

    func killRunningProcess() async {
      commandWasManuallyInterrupted = true
      await runningProcess?.tearDown()
    }

    private var commandWasManuallyInterrupted = false
    private var runningProcess: (any Execution)?

    @Dependency(\.shellService) private var shellService

  }

  public let name = "execute_command"

  public let description = """
    Request to execute a CLI command on the system. Use this when you need to perform system operations or run specific commands to accomplish any step in the user's task. You must tailor your command to the user's system and provide a clear explanation of what the command does. For command chaining, use the appropriate chaining syntax for the user's shell. Prefer to execute complex CLI commands over creating executable scripts, as they are more flexible and easier to run. Prefer relative commands and paths that avoid location sensitivity for terminal consistency, e.g: `touch ./testdata/example.file`, `dir ./examples/model1/data/yaml`, or `swift test ./cmd/package`. If directed by the user, you may open a terminal in a different directory by using the `cwd` parameter.
    DO NOT use this to create or update files. Instead describe them as code suggestions, and wait for the users to approve the changes.

    If the output exceeds \(truncationLimit) characters, output will be truncated in the middle before being returned to you.
    """

  public var displayName: String {
    "Execute Command"
  }

  public var shortDescription: String {
    "Executes CLI commands on the system for operations, builds, and tests."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "command": .object([
          "type": .string("string"),
          "description": .string("The command to execute."),
        ]),
        "cwd": .object([
          "type": .string("string"),
          "description": .string("Only if absolutely necessary, the directory in which to execute the command."),
        ]),
        "canModifySourceFiles": .object([
          "type": .string("boolean"),
          "description": .string("Whether the command can modify files tracked by the source control system."),
        ]),
        "canModifyDerivedFiles": .object([
          "type": .string("boolean"),
          "description": .string(
            "Whether the command can modify derived files that are unlikely to be tracked by the source control system. For instance `swift build` generates derived files but doesn't modify source files."),
        ]),
      ]),
      "required": .array([
        .string("command"),
        .string("canModifySourceFiles"),
        .string("canModifyDerivedFiles"),
      ]),
    ])
  }

  public func isAvailable(in mode: ChatMode) -> Bool {
    // TODO: add support for readonly uses of the terminal.
    mode == .agent
  }

  static let truncationLimit = 30000

}

extension String {
  /// Truncate the string to a specified limit, removing from the middle if needed.
  func trimmed(toNotExceed limit: Int) -> String {
    if count <= limit {
      return self
    }
    let i = index(startIndex, offsetBy: limit / 2)
    let j = index(endIndex, offsetBy: -limit / 2)
    return String(self[startIndex..<i]) + "... [\(count - limit) characters truncated] ..." + String(self[j..<endIndex])
  }
}

// MARK: - ExecuteCommandTool.Use + DisplayableToolUse

extension ExecuteCommandTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    AnyToolUseViewModel(ToolUseViewModel(
      command: input.command,
      status: status,
      stdout: stdoutStream,
      stderr: stderrStream,
      kill: killRunningProcess))
  }
}
