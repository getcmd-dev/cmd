// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
@testable import ExecuteCommandTool

extension ExecuteCommandToolTests {
  struct StreamRepresentationTests {
    @MainActor
    @Test("streamRepresentation returns nil when status is not completed")
    func test_streamRepresentationNilWhenNotCompleted() {
      let (status, _) = ExecuteCommandTool.Use.Status.makeStream(initial: .running)

      let viewModel = ToolUseViewModel(
        command: "ls -la",
        status: status,
        stdout: .Just(.Just(Data())),
        stderr: .Just(.Just(Data())),
        kill: { })

      #expect(viewModel.streamRepresentation == nil)
    }

    @MainActor
    @Test("streamRepresentation shows successful command execution")
    func test_streamRepresentationSuccessfulExecution() {
      // given
      let output = ExecuteCommandTool.Use.Output(
        output: "Hello World\n",
        exitCode: 0)
      let (status, _) = ExecuteCommandTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        command: "echo 'Hello World'",
        status: status,
        stdout: .Just(.Just(Data())),
        stderr: .Just(.Just(Data())),
        kill: { })

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Bash(echo 'Hello World')
          ⎿ Exit code: 0


        """)
    }

    @MainActor
    @Test("streamRepresentation shows failed command execution")
    func test_streamRepresentationFailedExecution() {
      // given
      let output = ExecuteCommandTool.Use.Output(
        output: "command not found: invalid-command",
        exitCode: 127)
      let (status, _) = ExecuteCommandTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        command: "invalid-command",
        status: status,
        stdout: .Just(.Just(Data())),
        stderr: .Just(.Just(Data())),
        kill: { })

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Bash(invalid-command)
          ⎿ Exit code: 127


        """)
    }

    @MainActor
    @Test("streamRepresentation shows tool failure with error")
    func test_streamRepresentationToolFailure() {
      // given
      let error = AppError("Command execution failed")
      let (status, _) = ExecuteCommandTool.Use.Status.makeStream(initial: .completed(.failure(error)))

      let viewModel = ToolUseViewModel(
        command: "test command",
        status: status,
        stdout: .Just(.Just(Data())),
        stderr: .Just(.Just(Data())),
        kill: { })

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Bash(test command)
          ⎿ Failed: Command execution failed


        """)
    }

    @MainActor
    @Test("streamRepresentation handles different exit codes")
    func test_streamRepresentationDifferentExitCodes() {
      // given
      let output1 = ExecuteCommandTool.Use.Output(output: "", exitCode: 0)
      let (status1, _) = ExecuteCommandTool.Use.Status.makeStream(initial: .completed(.success(output1)))
      let viewModel1 = ToolUseViewModel(
        command: "exit 0",
        status: status1,
        stdout: .Just(.Just(Data())),
        stderr: .Just(.Just(Data())),
        kill: { })

      let output2 = ExecuteCommandTool.Use.Output(output: "", exitCode: 1)
      let (status2, _) = ExecuteCommandTool.Use.Status.makeStream(initial: .completed(.success(output2)))
      let viewModel2 = ToolUseViewModel(
        command: "exit 1",
        status: status2,
        stdout: .Just(.Just(Data())),
        stderr: .Just(.Just(Data())),
        kill: { })

      // then
      #expect(viewModel1.streamRepresentation == """
        ⏺ Bash(exit 0)
          ⎿ Exit code: 0


        """)

      #expect(viewModel2.streamRepresentation == """
        ⏺ Bash(exit 1)
          ⎿ Exit code: 1


        """)
    }

    @MainActor
    @Test("streamRepresentation handles complex commands")
    func test_streamRepresentationComplexCommands() {
      // given
      let complexCommand = "find /usr/bin -name 'git' -type f | head -1"
      let output = ExecuteCommandTool.Use.Output(
        output: "/usr/bin/git\n",
        exitCode: 0)
      let (status, _) = ExecuteCommandTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        command: complexCommand,
        status: status,
        stdout: .Just(.Just(Data())),
        stderr: .Just(.Just(Data())),
        kill: { })

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Bash(\(complexCommand))
          ⎿ Exit code: 0


        """)
    }
  }

}
