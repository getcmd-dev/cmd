// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeBashTool

public final class ClaudeCodeBashTool: ExternalTool {

  public init() { }

  public final class Use: ExternalToolUse, Sendable {
    public init(
      callingTool: ClaudeCodeBashTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = input

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject
    public struct Input: Codable, Sendable {
      public let command: String
      public let timeout: Double?
      public let description: String?
    }

    public typealias Output = ExecuteCommandTool.Use.Output

    public let isReadonly = false

    public let callingTool: ClaudeCodeBashTool
    public let toolUseId: String
    public let input: Input
    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func receive(output: String) throws {
      let parsedOutput = Output(output: output, exitCode: 0)
      updateStatus.complete(with: .success(parsedOutput))
    }

  }

  public let name = "claude_code_Bash"

  public let description = """
    Executes a given bash command in a persistent shell session with optional timeout, ensuring proper handling and security measures.

    Before executing the command, please follow these steps:

    1. Directory Verification:
       - If the command will create new directories or files, first use the LS tool to verify the parent directory exists and is the correct location
       - For example, before running "mkdir foo/bar", first use LS to check that "foo" exists and is the intended parent directory

    2. Command Execution:
       - Always quote file paths that contain spaces with double quotes (e.g., cd "path with spaces/file.txt")
       - Examples of proper quoting:
         - cd "/Users/name/My Documents" (correct)
         - cd /Users/name/My Documents (incorrect - will fail)
         - python "/path/with spaces/script.py" (correct)
         - python /path/with spaces/script.py (incorrect - will fail)
       - After ensuring proper quoting, execute the command.
       - Capture the output of the command.

    Usage notes:
      - The command argument is required.
      - You can specify an optional timeout in milliseconds (up to 600000ms / 10 minutes). If not specified, commands will timeout after 120000ms (2 minutes).
      - It is very helpful if you write a clear, concise description of what this command does in 5-10 words.
      - If the output exceeds 30000 characters, output will be truncated before being returned to you.
      - VERY IMPORTANT: You MUST avoid using search commands like `find` and `grep`. Instead use Grep, Glob, or Task to search. You MUST avoid read tools like `cat`, `head`, `tail`, and `ls`, and use Read and LS to read files.
     - If you _still_ need to run `grep`, STOP. ALWAYS USE ripgrep at `rg` first, which all users have pre-installed.
      - When issuing multiple commands, use the ';' or '&&' operator to separate them. DO NOT use newlines (newlines are ok in quoted strings).
      - Try to maintain your current working directory throughout the session by using absolute paths and avoiding usage of `cd`. You may use `cd` if the User explicitly requests it.
    """

  public var displayName: String {
    "Bash (Claude Code)"
  }

  public var shortDescription: String {
    "Claude Code tool to execute bash commands with proper handling and security measures."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "command": .object([
          "type": .string("string"),
          "description": .string("The command to execute"),
        ]),
        "timeout": .object([
          "type": .string("number"),
          "description": .string("Optional timeout in milliseconds (max 600000)"),
        ]),
        "description": .object([
          "type": .string("string"),
          "description": .string(
            " Clear, concise description of what this command does in 5-10 words. Examples:\nInput: ls\nOutput: Lists files in current directory\n\nInput: git status\nOutput: Shows working tree status\n\nInput: npm install\nOutput: Installs package dependencies\n\nInput: mkdir foo\nOutput: Creates directory 'foo'"),
        ]),
      ]),
      "required": .array([.string("command")]),
      "additionalProperties": .bool(false),
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

}

// MARK: - ClaudeCodeBashTool.Use + DisplayableToolUse

extension ClaudeCodeBashTool.Use: DisplayableToolUse {
  public var body: AnyView {
    let (stdoutStream, stdoutContinuation) = BroadcastedStream<Data>.makeStream()
    Task {
      let output = await self.status.lastValue
      if
        case .completed(let output) = output,
        case .success(let success) = output,
        let strOutput = success.output
      {
        stdoutContinuation.yield(strOutput.utf8Data)
      }
      stdoutContinuation.finish()
    }

    let (stderrStream, stderrContinuation) = BroadcastedStream<Data>.makeStream()
    Task {
      _ = await self.status.lastValue
      stderrContinuation.finish()
    }

    let viewModel = ToolUseViewModel(
      command: input.command,
      status: status,
      stdout: Future.Just(stdoutStream),
      stderr: Future.Just(stderrStream),
      kill: { })
    return AnyView(ToolUseView(toolUse: viewModel))
  }
}
