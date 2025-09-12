// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
import Foundation
import LoggingServiceInterface
import SharedValuesFoundation
import ShellServiceInterface
import XcodeObserverServiceInterface

// MARK: - ExecuteExtensionRequestEvent

// TODO: make more generic than for extension
public struct ExecuteExtensionRequestEvent: AppEvent {

  public init(
    command: String,
    id: String,
    data: Data,
    completion: @escaping @Sendable (Result<any Encodable & Sendable, Error>) -> Void)
  {
    self.command = command
    self.id = id
    self.data = data
    self.completion = completion
  }

  public let command: String
  public let id: String
  public let data: Data
  public let completion: @Sendable (Result<any Encodable & Sendable, Error>) -> Void
}

extension UserDefinedXcodeShortcutExecutionInput {

  /// Execute the user defined Xcode shortcut command.
  public func execute(xcodeObserver: XcodeObserver, shellService: ShellService) async throws {
    defaultLogger.log("Preparing to execute user defined Xcode shortcut command: \(shellCommand)")

    // Prepare environment variables instead of string replacement
    var environmentVariables: [String: String] = [:]

    let xcodeState = xcodeObserver.state

    // Set FILEPATH
    if let currentFile = xcodeState.focusedTabURL {
      environmentVariables["FILEPATH"] = currentFile.path(percentEncoded: false)
    }
    // Set FILEPATH_FROM_GIT_ROOT
    if
      let currentFile = xcodeState.focusedTabURL,
      let gitRoot = try? await shellService.stdout(
        "git rev-parse --show-toplevel",
        cwd: currentFile.deletingLastPathComponent().path)
    {
      let relativePath = currentFile.path(percentEncoded: false).replacingOccurrences(of: gitRoot + "/", with: "")
      environmentVariables["FILEPATH_FROM_GIT_ROOT"] = relativePath
    }
    // Set XCODE_PROJECT_PATH
    if let projectPath = xcodeState.focusedWorkspace?.url {
      environmentVariables["XCODE_PROJECT_PATH"] = projectPath.path(percentEncoded: false)
    }
    // Set SELECTED_LINE_NUMBER_START and SELECTED_LINE_NUMBER_END
    if let selection = xcodeState.focusedWorkspace?.editors.first?.selections.first {
      environmentVariables["SELECTED_LINE_NUMBER_START"] = String(selection.start.line + 1)
      environmentVariables["SELECTED_LINE_NUMBER_END"] = String(selection.end.line + 1)
    }

    defaultLogger.log("Executing command with environment variables: \(environmentVariables)")

    // Execute the shell command with environment variables
    let res = try await shellService.run(shellCommand, useInteractiveShell: true, env: environmentVariables)
    if res.exitCode != 0 {
      throw AppError("Command exited with code \(res.exitCode): \(res.stderr ?? "No error output")")
    }
  }
}
