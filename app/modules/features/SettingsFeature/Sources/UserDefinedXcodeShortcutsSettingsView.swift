// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SettingsServiceInterface
import SharedValuesFoundation
import SwiftUI

// MARK: - UserDefinedXcodeShortcutsSettingsView

public struct UserDefinedXcodeShortcutsSettingsView: View {
  public init(userDefinedXcodeShortcuts: Binding<[UserDefinedXcodeShortcut]>) {
    _userDefinedXcodeShortcuts = userDefinedXcodeShortcuts
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading) {
        Text("Easily create new shortcuts in Xcode")
          .font(.headline)
          .padding(.bottom, 4)
        Text("You will find them under\n    `Editor > cmd`\n\nYou can set key bindings in\n    `Xcode > Settings > Key Bindings`")
      }
      // Environment variables info
      VStack(alignment: .leading, spacing: 8) {
        Text("Available Environment Variables")
          .font(.headline)

        VStack(alignment: .leading, spacing: 4) {
          envVarRow("FILEPATH", "Absolute path to current file")
          envVarRow("FILEPATH_FROM_GIT_ROOT", "File path relative to git repository root")
          envVarRow("SELECTED_LINE_NUMBER_START", "Start line of current selection")
          envVarRow("SELECTED_LINE_NUMBER_END", "End line of current selection")
          envVarRow("XCODE_PROJECT_PATH", "Path to current Xcode project")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
      }

      // Shortcuts list
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("User Defined Xcode Shortcuts")
            .font(.headline)

          Spacer()

          HoveredButton(
            action: {
              showingAddSheet = true
            },
            onHoverColor: colorScheme.tertiarySystemBackground,
            backgroundColor: colorScheme.secondarySystemBackground,
            padding: 8,
            cornerRadius: 6)
          {
            Text("Add Shortcut")
          }
          .disabled(!hasAvailableCommandIndex)
        }

        if userDefinedXcodeShortcuts.isEmpty {
          Text("No user defined Xcode shortcuts configured")
            .foregroundColor(.secondary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        } else {
          ForEach(userDefinedXcodeShortcuts.indices, id: \.self) { index in
            shortcutRow(for: $userDefinedXcodeShortcuts[index])
          }
        }

        if !hasAvailableCommandIndex {
          HStack {
            Image(systemName: "info.circle")
              .foregroundColor(.orange)
            Text(
              "Maximum of \(UserDefinedXcodeShortcutLimits.maxShortcuts) user defined Xcode shortcuts reached. Delete existing shortcuts to add new ones.")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding()
          .background(Color.orange.opacity(0.1))
          .cornerRadius(8)
        }
      }

      Spacer()
    }
    .sheet(isPresented: $showingAddSheet) {
      UserDefinedXcodeShortcutEditSheet(
        initialValue: nil,
        isNew: true,
        userDefinedXcodeShortcuts: userDefinedXcodeShortcuts,
        onSave: { shortcut in
          userDefinedXcodeShortcuts.append(shortcut)
          showingAddSheet = false
        },
        onCancel: {
          showingAddSheet = false
        })
    }
    .sheet(item: $editingShortcut) { shortcut in
      UserDefinedXcodeShortcutEditSheet(
        initialValue: shortcut,
        isNew: false,
        userDefinedXcodeShortcuts: userDefinedXcodeShortcuts,
        onSave: { updatedShortcut in
          if let index = userDefinedXcodeShortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            userDefinedXcodeShortcuts[index] = updatedShortcut
          }
          editingShortcut = nil
        },
        onCancel: {
          editingShortcut = nil
        })
    }
  }

  @Binding var userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut]

  @State private var editingShortcut: UserDefinedXcodeShortcut?
  @State private var showingAddSheet = false
  @Environment(\.colorScheme) private var colorScheme

  private var hasAvailableCommandIndex: Bool {
    userDefinedXcodeShortcuts.nextAvailableXcodeCommandIndex() != nil
  }

  private func envVarRow(_ name: String, _ description: String) -> some View {
    HStack(spacing: 0) {
      Text("$\(name)")
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(.primary)
        .textSelection(.enabled)
      Text(" - \(description)")
        .font(.caption)
        .foregroundColor(.secondary)
      Spacer()
    }
  }

  private func shortcutRow(for shortcut: Binding<UserDefinedXcodeShortcut>) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(shortcut.wrappedValue.name)
            .font(.body)
            .fontWeight(.medium)

          Spacer()

          Text("Command \(shortcut.wrappedValue.xcodeCommandIndex)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(4)
        }

        Text(shortcut.wrappedValue.command)
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if let keyBinding = shortcut.wrappedValue.keyBinding {
          HStack {
            Text("Key Binding:")
              .font(.subheadline)

            Text(keyBinding.display)
              .font(.system(.body, design: .monospaced))
              .foregroundColor(.secondary)
          }
        }
      }

      Spacer()

      HStack(spacing: 4) {
        HoveredButton(
          action: {
            editingShortcut = shortcut.wrappedValue
          },
          onHoverColor: colorScheme.secondarySystemBackground,
          padding: 6,
          cornerRadius: 6)
        {
          Image(systemName: "pencil")
            .font(.system(size: 12, weight: .medium))
        }

        HoveredButton(
          action: {
            if let index = userDefinedXcodeShortcuts.firstIndex(where: { $0.id == shortcut.id }) {
              userDefinedXcodeShortcuts.remove(at: index)
            }
          },
          onHoverColor: colorScheme.secondarySystemBackground,
          padding: 6,
          cornerRadius: 6)
        {
          Image(systemName: "trash")
            .font(.system(size: 12, weight: .medium))
        }
      }
    }
    .padding(12)
    .background(Color.gray.opacity(0.05))
    .cornerRadius(8)
  }
}

// MARK: - UserDefinedXcodeShortcutEditSheet

private struct UserDefinedXcodeShortcutEditSheet: View {

  init(
    initialValue: UserDefinedXcodeShortcut?,
    isNew: Bool,
    userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut],
    onSave: @escaping (UserDefinedXcodeShortcut) -> Void,
    onCancel: @escaping () -> Void)
  {
    let defaultIndex: Int =
      if isNew {
        userDefinedXcodeShortcuts.nextAvailableXcodeCommandIndex() ?? 0
      } else {
        initialValue?.xcodeCommandIndex ?? 0
      }

    _shortcut = .init(initialValue: initialValue ?? UserDefinedXcodeShortcut(
      name: "",
      command: "",
      xcodeCommandIndex: defaultIndex))
    self.isNew = isNew
    self.userDefinedXcodeShortcuts = userDefinedXcodeShortcuts
    self.onSave = onSave
    self.onCancel = onCancel
  }

  let isNew: Bool
  let userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut]
  let onSave: (UserDefinedXcodeShortcut) -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(isNew ? "Add User Defined Xcode Shortcut" : "Edit User Defined Xcode Shortcut")
          .font(.headline)

        Text("This will be mapped to Xcode command index \(shortcut.xcodeCommandIndex)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Name")
          .font(.subheadline)
          .fontWeight(.medium)
        TextField("Open file in GitHub", text: $shortcut.name)
          .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Shell Command")
          .font(.subheadline)
          .fontWeight(.medium)
        TextField("open \"https://github.com/myorg/myrepo/$FILEPATH_FROM_GIT_ROOT\"", text: $shortcut.command)
          .textFieldStyle(.roundedBorder)
      }
      // TODO: complete setting key bindings.
      // Xcode key bindings are store at ~/Library/Developer/Xcode/UserData/KeyBindings/Default.idekeybindings in XML format.
      // This would need to be modified _after_ Xcode has added an entry for the shortcut, which likely requires Xcode to be restarted.
      // Alternatively, the key binding could be managed directly through cmd.

//        VStack(alignment: .leading, spacing: 8) {
//          Text("Optional key binding")
//                .font(.subheadline)
//                .fontWeight(.medium)
//            KeyBindingInputView(keyboardShortcut: $shortcut.keyBinding)
//        }

      HStack {
        Spacer()

        HoveredButton(
          action: {
            onSave(UserDefinedXcodeShortcut(
              id: isNew ? UUID() : shortcut.id,
              name: shortcut.name,
              command: shortcut.command,
              keyBinding: shortcut.keyBinding,
              xcodeCommandIndex: shortcut.xcodeCommandIndex))
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 5,
          cornerRadius: 6)
        {
          Text("Save")
        }
        .disabled(shortcut.name.isEmpty || shortcut.command.isEmpty)
      }
    }
    .padding()
    .frame(width: 500, height: 300)
  }

  @State private var shortcut: UserDefinedXcodeShortcut
  @Environment(\.colorScheme) private var colorScheme

}

extension [UserDefinedXcodeShortcut] {

  func nextAvailableXcodeCommandIndex() -> Int? {
    let usedIndexes = Set(self.map(\.xcodeCommandIndex))
    for index in 0..<UserDefinedXcodeShortcutLimits.maxShortcuts {
      if !usedIndexes.contains(index) {
        return index
      }
    }
    return nil
  }
}
