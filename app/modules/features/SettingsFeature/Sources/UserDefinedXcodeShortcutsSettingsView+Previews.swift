// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import SettingsServiceInterface
import SharedValuesFoundation
import SwiftUI

#if DEBUG

// MARK: - Preview Data

private let sampleShortcuts = [
  UserDefinedXcodeShortcut(
    id: UUID(),
    name: "Open in GitHub",
    command: "open \"https://github.com/myorg/myrepo/$FILEPATH_FROM_GIT_ROOT\"",
    keyBinding: nil,
    xcodeCommandIndex: 0),
  UserDefinedXcodeShortcut(
    id: UUID(),
    name: "Format Code",
    command: "swift-format format --in-place $FILEPATH",
    keyBinding: .init(
      key: "F",
      modifiers: [.command, .shift]),
    xcodeCommandIndex: 1),
  UserDefinedXcodeShortcut(
    id: UUID(),
    name: "Run Tests",
    command: "cd \"$XCODE_PROJECT_PATH\" && xcodebuild test -scheme MyApp",
    keyBinding: nil,
    xcodeCommandIndex: 2),
]

// MARK: - ShortcutRow Previews

#Preview("ShortcutRow - Basic") {
  ShortcutRow(
    userDefinedXcodeShortcuts: .constant(sampleShortcuts),
    editingShortcut: .constant(nil),
    shortcut: sampleShortcuts[0])
    .padding()
}

#Preview("ShortcutRow - With Key Binding") {
  ShortcutRow(
    userDefinedXcodeShortcuts: .constant(sampleShortcuts),
    editingShortcut: .constant(nil),
    shortcut: sampleShortcuts[1])
    .padding()
}

#Preview("ShortcutRow - Long Command") {
  ShortcutRow(
    userDefinedXcodeShortcuts: .constant(sampleShortcuts),
    editingShortcut: .constant(nil),
    shortcut: sampleShortcuts[2])
    .padding()
}

// MARK: - EditingShortcutRow Previews

#Preview("EditingShortcutRow - New Shortcut") {
  EditingShortcutRow(
    userDefinedXcodeShortcuts: .constant(sampleShortcuts),
    editingShortcut: .constant(nil),
    shortcut: UserDefinedXcodeShortcut(
      name: "",
      command: "",
      xcodeCommandIndex: 3),
    isNew: true,
    onSave: { _ in },
    onCancel: { })
    .padding()
}

#Preview("EditingShortcutRow - Edit Existing") {
  EditingShortcutRow(
    userDefinedXcodeShortcuts: .constant(sampleShortcuts),
    editingShortcut: .constant(sampleShortcuts[0]),
    shortcut: sampleShortcuts[0],
    isNew: false)
    .padding()
}

#Preview("EditingShortcutRow - Filled Form") {
  @Previewable @State var shortcut = UserDefinedXcodeShortcut(
    name: "Test Shortcut",
    command: "echo 'Hello World'",
    xcodeCommandIndex: 0)

  return EditingShortcutRow(
    userDefinedXcodeShortcuts: .constant([shortcut]),
    editingShortcut: .constant(shortcut),
    shortcut: shortcut,
    isNew: true,
    onSave: { _ in },
    onCancel: { })
    .padding()
}

// MARK: - UserDefinedXcodeShortcutsSettingsView Previews

#Preview("Settings View - Empty") {
  UserDefinedXcodeShortcutsSettingsView(
    userDefinedXcodeShortcuts: .constant([]))
    .padding()
    .frame(width: 600, height: 800)
}

#Preview("Settings View - With Shortcuts") {
  UserDefinedXcodeShortcutsSettingsView(
    userDefinedXcodeShortcuts: .constant(sampleShortcuts))
    .padding()
    .frame(width: 600, height: 800)
}

#Preview("Settings View - Max Shortcuts Reached") {
  let maxShortcuts = Array(0..<UserDefinedXcodeShortcutLimits.maxShortcuts).map { index in
    UserDefinedXcodeShortcut(
      id: UUID(),
      name: "Shortcut \(index + 1)",
      command: "echo 'Command \(index + 1)'",
      keyBinding: nil,
      xcodeCommandIndex: index)
  }

  return UserDefinedXcodeShortcutsSettingsView(
    userDefinedXcodeShortcuts: .constant(maxShortcuts))
    .padding()
    .frame(width: 600, height: 800)
}

#Preview("Settings View - Dark Mode") {
  UserDefinedXcodeShortcutsSettingsView(
    userDefinedXcodeShortcuts: .constant(sampleShortcuts))
    .padding()
    .frame(width: 600, height: 800)
    .preferredColorScheme(.dark)
}

// MARK: - Component Comparison Preview

#Preview("Component States Comparison") {
  VStack(spacing: 20) {
    Group {
      Text("Display Mode")
        .font(.headline)

      ShortcutRow(
        userDefinedXcodeShortcuts: .constant(sampleShortcuts),
        editingShortcut: .constant(nil),
        shortcut: sampleShortcuts[0])

      Text("Editing Mode")
        .font(.headline)

      EditingShortcutRow(
        userDefinedXcodeShortcuts: .constant(sampleShortcuts),
        editingShortcut: .constant(sampleShortcuts[0]),
        shortcut: sampleShortcuts[0],
        isNew: false)
    }
  }
  .padding()
}

#endif
