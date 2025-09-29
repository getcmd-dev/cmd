// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Dependencies
import LLMFoundation
import ShellServiceInterface
import SwiftUI

#if DEBUG
@MainActor let enabledExecutable = ObservableValue("/usr/local/bin/claude")
@MainActor let disabledExecutable = ObservableValue("")
@MainActor let executableWithCustomPath = ObservableValue("")

func createShellService(installedExecutablePath: String?) -> ShellService {
  let mockShellService = MockShellService()
  mockShellService.onRun = { _, _, _, _, _ in
    if let installedExecutablePath {
      return CommandExecutionResult(
        exitCode: 0,
        stdout: installedExecutablePath)
    }
    return CommandExecutionResult(
      exitCode: 1,
      stderr: "not found")
  }
  return mockShellService
}

#Preview("Agent enabled") {
  ExternalAgentCard(
    externalAgent: LLMProvider.claudeCode.externalAgent!,
    executable: enabledExecutable.binding)
    .frame(minHeight: 300)
}

#Preview("Agent disabled") {
  withDependencies {
    $0.shellService = createShellService(installedExecutablePath: nil)
  }
  operation: {
    ExternalAgentCard(
      externalAgent: LLMProvider.claudeCode.externalAgent!,
      executable: disabledExecutable.binding)
      .frame(minHeight: 300)
  }
}

#Preview("Agent disabled and installed at default path") {
  withDependencies {
    $0.shellService = createShellService(installedExecutablePath: "/custom/path/to/claude")
  }
  operation: {
    ExternalAgentCard(
      externalAgent: LLMProvider.claudeCode.externalAgent!,
      executable: executableWithCustomPath.binding)
      .frame(minHeight: 300)
  }
}

#endif
