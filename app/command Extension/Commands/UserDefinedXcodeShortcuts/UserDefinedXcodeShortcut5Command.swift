// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

final class UserDefinedXcodeShortcut5Command: BaseUserDefinedXcodeShortcutCommand, @unchecked Sendable {
  required init(name: String? = nil, command: String? = nil) {
    super.init(shortcutIndex: 5, name: name, command: command)
  }
}
