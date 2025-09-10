// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppExtension
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import SharedValuesFoundation
import XcodeKit

final class SourceEditorExtension: NSObject, XCSourceEditorExtension {

  var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
    defaultLogger.log("creating commandDefinitions")
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""

    // Base commands
    var commands: [CommandType] = [
      ApplyEditCommand(),
      OpenInCursorCommand(),
      ReloadSettingsCommand(),
    ]

    // Configure and add user defined Xcode shortcut commands based on settings
    configureUserDefinedXcodeShortcutCommands()
    commands.append(contentsOf: userDefinedXcodeShortcutCommands)

    return commands.map { $0.makeCommandDefinition(identifierPrefix: bundleIdentifier) }
  }

  func extensionDidFinishLaunching() {
    #if RELEASE
    if AppExtensionScope.shared.sharedUserDefaults.bool(forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp) != true {
      openContainingAppIfNecessary()
    }
    #endif
  }

  private var userDefinedXcodeShortcutCommands: [CommandType] = []

  private func configureUserDefinedXcodeShortcutCommands() {
    defaultLogger.log("Configuring user defined Xcode shortcut commands")
    userDefinedXcodeShortcutCommands.removeAll()

    // Load user defined Xcode shortcuts from settings
    let settings = AppExtensionScope.shared.settingsService.values()
    let enabledUserDefinedShortcuts = settings.userDefinedXcodeShortcuts.filter(\.isEnabled)

    defaultLogger.log("Found \(enabledUserDefinedShortcuts.count) enabled user defined Xcode shortcuts")

    // Create command instances for each enabled shortcut (max from shared constant)
    for (index, shortcut) in enabledUserDefinedShortcuts.enumerated() {
      guard index < UserDefinedXcodeShortcutLimits.maxShortcuts else {
        defaultLogger
          .error(
            "Too many user defined Xcode shortcuts configured. Only first \(UserDefinedXcodeShortcutLimits.maxShortcuts) will be available.")
        break
      }

      guard index < BaseUserDefinedXcodeShortcutCommand.subClasses.count else {
        defaultLogger.error("No command class available for index \(index)")
        continue
      }

      let commandClass = BaseUserDefinedXcodeShortcutCommand.subClasses[index]
      let command = commandClass.init()

      userDefinedXcodeShortcutCommands.append(command)
      defaultLogger.log("Configured user defined Xcode shortcut: \(shortcut.name)")
    }

    defaultLogger.log("Configured \(userDefinedXcodeShortcutCommands.count) user defined Xcode shortcut commands")
  }

  private func openContainingAppIfNecessary() {
    do {
      try OpenHostApp.openHostApp()
    } catch {
      defaultLogger.error("Error opening containing application: \(error)")
    }
  }

}
