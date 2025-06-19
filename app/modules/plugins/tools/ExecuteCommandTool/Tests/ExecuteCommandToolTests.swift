// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import ServerServiceInterface
import ShellServiceInterface
import SwiftTesting
import Testing
@testable import ExecuteCommandTool

struct ExecuteCommandToolTests {

  @Test
  func trimmedToNotExceedReturnsOriginalStringWhenUnderLimit() {
    let text = "Hello, World!"
    let result = text.trimmed(toNotExceed: 20)
    #expect(result == "Hello, World!")
  }

  @Test
  func trimmedToNotExceedTruncatesLongString() {
    let text = "This is a very long string that should be truncated in the middle"
    let result = text.trimmed(toNotExceed: 30)
    #expect(result.hasPrefix("This is a very"))
    #expect(result.hasSuffix("d in the middle"))
    #expect(result.contains("... [35 characters truncated] ..."))
    #expect(result.count < text.count) // Should be shorter than original
  }

  @Test
  func completesWithTheExpectedOutcome() async throws {
    let shellService = MockShellService()
    shellService.onRun = { command, cwd, useInteractiveShell, _ in
      #expect(command == "ls -la")
      #expect(cwd == "/path/to/root/path/to/dir")
      #expect(useInteractiveShell == true)
      return CommandExecutionResult(
        exitCode: 0,
        mergedOutput: "file.txt")
    }

    let toolUse = withDependencies {
      $0.shellService = shellService
    } operation: {
      let toolUse = ExecuteCommandTool().use(
        toolUseId: "123",
        input: .init(
          command: "ls -la",
          cwd: "./path/to/dir",
          canModifySourceFiles: false,
          canModifyDerivedFiles: false),
        context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))
      toolUse.startExecuting()
      return toolUse
    }
    let result = try await toolUse.output
    #expect(result.exitCode == 0)
    #expect(result.output == "file.txt")
  }

  @Test
  func completesWithAFailureWhenSomethingWentWrong() async throws {
    let shellService = MockShellService()
    shellService.onRun = { _, _, _, _ in
      struct ShellError: Error {
        let message: String
      }
      throw ShellError(message: "Command failed")
    }

    let toolUse = withDependencies {
      $0.shellService = shellService
    } operation: {
      let toolUse = ExecuteCommandTool().use(
        toolUseId: "123",
        input: .init(
          command: "ls -la",
          cwd: "./path/to/dir",
          canModifySourceFiles: false,
          canModifyDerivedFiles: false),
        context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))
      toolUse.startExecuting()
      return toolUse
    }
    await #expect(throws: Error.self, performing: {
      try await toolUse.output
    })
  }
}
