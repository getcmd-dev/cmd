// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import Dependencies
import ExtensionEventsInterface
import Foundation
import LoggingServiceInterface
import SharedValuesFoundation
import ShellServiceInterface
import XcodeObserverServiceInterface

// MARK: - ExtensionCommandHandler

// TODO: Remove @unchecked when https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed
public final class ExtensionCommandHandler: @unchecked Sendable {

  public init() {
    appEventHandlerRegistry.registerHandler { [weak self] event in
      await self?.handle(appEvent: event) ?? false
    }
  }

  @Dependency(\.appEventHandlerRegistry) private var appEventHandlerRegistry
  @Dependency(\.shellService) private var shellService
  @Dependency(\.xcodeObserver) private var xcodeObserver

  private func handle(appEvent: AppEvent) async -> Bool {
    if let appEvent = appEvent as? ExecuteExtensionRequestEvent {
      do {
        switch appEvent.command {
        case ExtensionCommandKeys.openInCursor:
          let xcodeState = xcodeObserver.state
          guard let currentFile = xcodeState.focusedTabURL else {
            defaultLogger.error("No active file found")
            return false
          }
          var lineDescriptor = ""
          if
            let line = xcodeState.focusedWorkspace?.editors.first(where: {
              $0.fileName == currentFile.lastPathComponent
            })?.selections.first?.start.line
          {
            lineDescriptor = ":\(line + 1)"
          }

          try await shellService
            .run(
              "/Applications/Cursor.app/Contents/Resources/app/bin/code -g \"\(currentFile.path(percentEncoded: false))\(lineDescriptor)\"",
              useInteractiveShell: false)
          defaultLogger.log("Completed command")
          appEvent.completion(.success(EmptyResult()))
          return true

        case ExtensionCommandKeys.executeUserDefinedXcodeShortcut:
          let input = try JSONDecoder().decode(ExtensionRequest<UserDefinedXcodeShortcutExecutionInput>.self, from: appEvent.data)
            .input

          defaultLogger.log("Executing user defined Xcode shortcut: \(input.shortcutId)")

          do {
            try await executeUserDefinedXcodeShortcut(input: input)
            defaultLogger.log("User defined Xcode shortcut completed successfully: \(input.shortcutId)")
            appEvent.completion(.success(EmptyResult()))
            return true
          } catch {
            defaultLogger.error("User defined Xcode shortcut execution failed: \(error)")
            appEvent.completion(.failure(error))
            return false
          }

        default:
          return false
        }
      } catch {
        defaultLogger.error("Error running shell command: \(error)")
        appEvent.completion(.failure(error))
      }
    }
    return false
  }

  private func executeUserDefinedXcodeShortcut(input: UserDefinedXcodeShortcutExecutionInput) async throws {
    defaultLogger.log("Preparing to execute user defined Xcode shortcut command: \(input.shellCommand)")

    // Prepare environment variables instead of string replacement
    var environmentVariables: [String: String] = [:]

    let xcodeState = xcodeObserver.state
      
    // Set FILEPATH
    if let currentFile = xcodeState.focusedTabURL {
      environmentVariables["FILEPATH"] = currentFile.path(percentEncoded: false)
    }
    // Set FILEPATH_FROM_GIT_ROOT
    if let currentFile = xcodeState.focusedTabURL,
        let gitRoot = try? await shellService.stdout("git rev-parse --show-toplevel", cwd: currentFile.deletingLastPathComponent().path)  {
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
    try await shellService.run(input.shellCommand, useInteractiveShell: true, env: environmentVariables)
  }
}

// MARK: - EmptyResult

private struct EmptyResult: Encodable { }
