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
        case ExtensionCommandKeys.executeUserDefinedXcodeShortcut:
          let input = try JSONDecoder().decode(ExtensionRequest<UserDefinedXcodeShortcutExecutionInput>.self, from: appEvent.data)
            .input

          defaultLogger.log("Executing user defined Xcode shortcut: \(input.shortcutId)")

          do {
            try await input.execute(xcodeObserver: xcodeObserver, shellService: shellService)
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
}

// MARK: - EmptyResult

private struct EmptyResult: Encodable { }
