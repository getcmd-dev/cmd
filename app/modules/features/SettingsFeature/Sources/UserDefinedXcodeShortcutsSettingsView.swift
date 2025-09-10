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

          Button("Add Shortcut") {
            showingAddSheet = true
          }
          .buttonStyle(.borderedProminent)
          .disabled(userDefinedXcodeShortcuts.count >= UserDefinedXcodeShortcutLimits.maxShortcuts)
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

        if userDefinedXcodeShortcuts.count >= UserDefinedXcodeShortcutLimits.maxShortcuts {
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
        shortcut: .constant(UserDefinedXcodeShortcut(name: "", command: "")),
        isNew: true,
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
        shortcut: .constant(shortcut),
        isNew: false,
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

  private func envVarRow(_ name: String, _ description: String) -> some View {
    HStack {
      Text("$\(name)")
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(.primary)
      Text("- \(description)")
        .font(.caption)
        .foregroundColor(.secondary)
      Spacer()
    }
  }

  private func shortcutRow(for shortcut: Binding<UserDefinedXcodeShortcut>) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(shortcut.wrappedValue.name)
          .font(.subheadline)
          .fontWeight(.medium)

        Text(shortcut.wrappedValue.command)
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
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
  @Binding var shortcut: UserDefinedXcodeShortcut

  let isNew: Bool
  let onSave: (UserDefinedXcodeShortcut) -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(isNew ? "Add User Defined Xcode Shortcut" : "Edit User Defined Xcode Shortcut")
        .font(.headline)

      VStack(alignment: .leading, spacing: 8) {
        Text("Name")
          .font(.subheadline)
          .fontWeight(.medium)
        TextField("Open file in GitHub", text: $name)
          .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Shell Command")
          .font(.subheadline)
          .fontWeight(.medium)
        TextField("open \"https://github.com/myorg/$FILEPATH_FROM_GIT_ROOT\"", text: $command)
          .textFieldStyle(.roundedBorder)
      }

      HStack {
        Spacer()

        Button("Save") {
          onSave(UserDefinedXcodeShortcut(
            id: isNew ? UUID() : shortcut.id,
            name: name,
            command: command,
            isEnabled: true))
        }
        .buttonStyle(.borderedProminent)
        .disabled(name.isEmpty || command.isEmpty)
      }
    }
    .padding()
    .frame(width: 500, height: 300)
    .onAppear {
      name = shortcut.name
      command = shortcut.command
    }
  }

  @State private var name = ""
  @State private var command = ""

}
