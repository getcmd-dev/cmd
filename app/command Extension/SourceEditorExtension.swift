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

    // Configure and add user defined Xcode shortcut commands based on settings
    var commands = getUserDefinedXcodeShortcutCommands()

    // Base commands
    commands.append(contentsOf: [
      ApplyEditCommand(),
      ReloadSettingsCommand(),
    ])

    return commands.map { $0.makeCommandDefinition(identifierPrefix: bundleIdentifier) }
  }

  func extensionDidFinishLaunching() {
    #if RELEASE
    if AppExtensionScope.shared.sharedUserDefaults.bool(forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp) != true {
      openContainingAppIfNecessary()
    }
    #endif
  }

  private func getUserDefinedXcodeShortcutCommands() -> [CommandType] {
    defaultLogger.log("Reading user defined Xcode shortcut commands")
    var result: [CommandType] = []

    // Load user defined Xcode shortcuts from settings
    let settings = AppExtensionScope.shared.settingsService.values()

    defaultLogger.log("Found \(settings.userDefinedXcodeShortcuts.count) enabled user defined Xcode shortcuts")

    // Create command instances using stable xcodeCommandIndex
    for shortcut in settings.userDefinedXcodeShortcuts {
      let commandIndex = shortcut.xcodeCommandIndex

      guard commandIndex >= 0, commandIndex < UserDefinedXcodeShortcutLimits.maxShortcuts else {
        defaultLogger.error("Invalid xcode command index \(commandIndex) for shortcut '\(shortcut.name)'")
        continue
      }

      guard commandIndex < BaseUserDefinedXcodeShortcutCommand.subClasses.count else {
        defaultLogger.error("No command class available for index \(commandIndex)")
        continue
      }

      let commandClass = BaseUserDefinedXcodeShortcutCommand.subClasses[commandIndex]
      let command = commandClass.init()

      result.append(command)
      defaultLogger.log("User defined Xcode shortcut: '\(shortcut.name)' mapped to command index \(commandIndex)")
    }

    defaultLogger.log("Created \(result.count) user defined Xcode shortcut commands")
    return result
  }

  private func openContainingAppIfNecessary() {
    do {
      try OpenHostApp.openHostApp()
    } catch {
      defaultLogger.error("Error opening containing application: \(error)")
    }
  }

}
