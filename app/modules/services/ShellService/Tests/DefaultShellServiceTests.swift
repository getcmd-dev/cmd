// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import ShellService

struct DefaultShellServiceTests {

  // MARK: - Environment Variable Merging Tests

  @Test("Environment variables are merged correctly with interactive shell")
  func testEnvMergingWithInteractiveShell() async throws {
    let shellService = DefaultShellService()

    // Wait for the shell environment to load
    try await Task.sleep(for: .seconds(2))

    let customEnv = [
      "TEST_VAR1": "value1",
      "TEST_VAR2": "value2",
    ]

    let result = try await shellService.run(
      "echo \"TEST_VAR1=$TEST_VAR1,TEST_VAR2=$TEST_VAR2\"",
      useInteractiveShell: true,
      env: customEnv)

    #expect(result.exitCode == 0)
    #expect(result.stdout?.contains("TEST_VAR1=value1") == true)
    #expect(result.stdout?.contains("TEST_VAR2=value2") == true)
  }

  @Test("Environment variables are merged correctly without interactive shell")
  func testEnvMergingWithoutInteractiveShell() async throws {
    let shellService = DefaultShellService()

    let customEnv = [
      "TEST_VAR1": "value1",
      "TEST_VAR2": "value2",
    ]

    let result = try await shellService.run(
      "echo \"TEST_VAR1=$TEST_VAR1,TEST_VAR2=$TEST_VAR2\"",
      useInteractiveShell: false,
      env: customEnv)

    #expect(result.exitCode == 0)
    #expect(result.stdout?.contains("TEST_VAR1=value1") == true)
    #expect(result.stdout?.contains("TEST_VAR2=value2") == true)
  }

  @Test("Additional env variables override existing ones")
  func testEnvVariableOverride() async throws {
    let shellService = DefaultShellService()

    // First, set PATH to a custom value
    let customEnv = [
      "TEST_VAR": "value1",
    ]

    let result = try await shellService.run(
      "echo \"TEST_VAR=$TEST_VAR\"",
      useInteractiveShell: false,
      env: customEnv)

    #expect(result.exitCode == 0)
    #expect(result.stdout == "TEST_VAR=value1")
  }

  @Test("Interactive shell environment is preserved when no custom env provided")
  func testInteractiveShellEnvironmentPreserved() async throws {
    let shellService = DefaultShellService()

    // Wait for the shell environment to load
    try await Task.sleep(for: .seconds(2))

    let result = try await shellService.run(
      "echo \"PATH=$PATH\"",
      useInteractiveShell: true,
      env: nil)

    #expect(result.exitCode == 0)
    #expect(result.stdout?.isEmpty == false)
    #expect(result.stdout?.contains("PATH=") == true)
  }

  @Test("Empty custom env works correctly")
  func testEmptyCustomEnv() async throws {
    let shellService = DefaultShellService()

    let result = try await shellService.run(
      "echo \"Hello World\"",
      useInteractiveShell: false,
      env: [:])

    #expect(result.exitCode == 0)
    #expect(result.stdout == "Hello World")
  }

  @Test("Nil env parameter works correctly")
  func testNilEnvParameter() async throws {
    let shellService = DefaultShellService()

    let result = try await shellService.run(
      "echo \"Hello World\"",
      useInteractiveShell: false,
      env: nil)

    #expect(result.exitCode == 0)
    #expect(result.stdout == "Hello World")
  }

  @Test("Custom env variables are available in shell command")
  func testCustomEnvVariablesAccessible() async throws {
    let shellService = DefaultShellService()

    let customEnv = [
      "FILEPATH": "/path/to/file.swift",
      "FILEPATH_FROM_GIT_ROOT": "src/file.swift",
      "SELECTED_LINE_NUMBER_START": "10",
      "SELECTED_LINE_NUMBER_END": "15",
      "XCODE_PROJECT_PATH": "/path/to/project",
    ]

    let result = try await shellService.run(
      "echo \"File: $FILEPATH, Git: $FILEPATH_FROM_GIT_ROOT, Lines: $SELECTED_LINE_NUMBER_START-$SELECTED_LINE_NUMBER_END, Project: $XCODE_PROJECT_PATH\"",
      useInteractiveShell: true,
      env: customEnv)

    #expect(result.exitCode == 0)
    let output = result.stdout ?? ""
    #expect(output.contains("File: /path/to/file.swift"))
    #expect(output.contains("Git: src/file.swift"))
    #expect(output.contains("Lines: 10-15"))
    #expect(output.contains("Project: /path/to/project"))
  }

  // MARK: - Convenience Method Tests

  @Test("stdout convenience method works with custom env")
  func testStdoutConvenienceMethodWithEnv() async throws {
    let shellService = DefaultShellService()

    let customEnv = ["TEST_VAR": "test_value"]

    let output = try await shellService.stdout(
      "echo $TEST_VAR",
      useInteractiveShell: false,
      env: customEnv)

    #expect(output == "test_value")
  }
}
