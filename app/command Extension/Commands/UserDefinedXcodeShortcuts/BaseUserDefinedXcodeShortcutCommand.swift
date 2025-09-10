// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import SharedValuesFoundation
import XcodeKit

// MARK: - UserDefinedShortcutCommand

protocol UserDefinedShortcutCommand {
  init(name: String?, command: String?)
}

// MARK: - BaseUserDefinedXcodeShortcutCommand

class BaseUserDefinedXcodeShortcutCommand: CommandType, UserDefinedShortcutCommand, @unchecked Sendable {

  // MARK: - Initialization

  required init(name: String?, command: String?) {
    shortcutIndex = -1
    userDefinedShortcutName = name
    shellCommand = command
    super.init()
  }

  init(shortcutIndex: Int, name: String? = nil, command: String? = nil) {
    self.shortcutIndex = shortcutIndex
    userDefinedShortcutName = name
    shellCommand = command
    super.init()
  }

  static let subClasses: [BaseUserDefinedXcodeShortcutCommand.Type] = [
    UserDefinedXcodeShortcut1Command.self,
    UserDefinedXcodeShortcut2Command.self,
    UserDefinedXcodeShortcut3Command.self,
    UserDefinedXcodeShortcut4Command.self,
    UserDefinedXcodeShortcut5Command.self,
    UserDefinedXcodeShortcut6Command.self,
    UserDefinedXcodeShortcut7Command.self,
    UserDefinedXcodeShortcut8Command.self,
    UserDefinedXcodeShortcut9Command.self,
    UserDefinedXcodeShortcut10Command.self,
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
