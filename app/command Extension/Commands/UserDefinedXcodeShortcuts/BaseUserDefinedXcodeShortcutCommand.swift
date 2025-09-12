// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppExtension
import ExtensionEventsInterface
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import SettingsServiceInterface
import SharedValuesFoundation
import XcodeKit

// MARK: - UserDefinedShortcutCommand

// MARK: - BaseUserDefinedXcodeShortcutCommand

class BaseUserDefinedXcodeShortcutCommand: CommandType, @unchecked Sendable {

  // MARK: - Initialization

  required override convenience init() {
    self.init(shortcutIndex: -1)
  }

  init(shortcutIndex: Int) {
    defaultLogger.log("\(type(of: self)): Initializing with index \(shortcutIndex)")
    let settings = AppExtensionScope.shared.settingsService.value(for: \.userDefinedXcodeShortcuts)
    self.shortcutIndex = shortcutIndex

    // Find shortcut by xcodeCommandIndex instead of array position
    if let shortcut = settings.first(where: { $0.xcodeCommandIndex == shortcutIndex }) {
      userDefinedShortcutName = shortcut.name
      shellCommand = shortcut.command
    } else {
      userDefinedShortcutName = nil
      shellCommand = nil
    }
    super.init()
  }

  static let subClasses: [BaseUserDefinedXcodeShortcutCommand.Type] = [
    UserDefinedXcodeShortcut0Command.self,
    UserDefinedXcodeShortcut1Command.self,
    UserDefinedXcodeShortcut2Command.self,
    UserDefinedXcodeShortcut3Command.self,
    UserDefinedXcodeShortcut4Command.self,
    UserDefinedXcodeShortcut5Command.self,
    UserDefinedXcodeShortcut6Command.self,
    UserDefinedXcodeShortcut7Command.self,
    UserDefinedXcodeShortcut8Command.self,
    UserDefinedXcodeShortcut9Command.self,
  ]

  let userDefinedShortcutName: String?
  let shellCommand: String?

  // MARK: - CommandType Implementation

  override var name: String {
    userDefinedShortcutName ?? defaultName
  }

  override var timeoutAfter: TimeInterval { 10 }

  override func handle(_: XCSourceEditorCommandInvocation) async throws {
    guard let command = shellCommand else {
      defaultLogger.error("\(type(of: self)): No shell command configured")
      return
    }

    let response: EmptyResponse = try await LocalServer().send(
      command: ExtensionCommandKeys.executeUserDefinedXcodeShortcut,
      input: UserDefinedXcodeShortcutExecutionInput(
        shortcutId: shortcutId,
        shellCommand: command))
    _ = response
  }

  private let shortcutIndex: Int

  // MARK: - Private Properties

  private var defaultName: String {
    "User Defined Shortcut \(shortcutIndex)"
  }

  private var shortcutId: String {
    "user_defined_shortcut_\(shortcutIndex)"
  }

}
