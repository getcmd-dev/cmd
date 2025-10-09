// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import ExtensionEventsInterface
import PermissionsServiceInterface
import SettingsServiceInterface
import SharedValuesFoundation
import ShellServiceInterface
import SwiftUI
import XcodeObserverServiceInterface

// MARK: - UserDefinedXcodeShortcutsSettingsView

struct UserDefinedXcodeShortcutsSettingsView: View {
  init(userDefinedXcodeShortcuts: Binding<[UserDefinedXcodeShortcut]>) {
    _userDefinedXcodeShortcuts = userDefinedXcodeShortcuts
  }

  @Binding var userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Documentation link
      PlainLink(
        "Documentation",
        destination: URL(string: "https://docs.getcmd.dev/pages/xcode-shortcuts")!)

      // Xcode Extension permission warning
      if !isXcodeExtensionPermissionGranted {
        WarningView(
          title: "Xcode Extension permissions required",
          subtext:
          Text(
            "Xcode shortcuts need Xcode Extension permissions to work. Please grant permissions in \(Text("[**Settings > Login Items & Extensions > Xcode Source Editor**](x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.dt.Xcode.extension.source-editor)"))."))
      }

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
              showingAddForm = true
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

        ScrollView {
          LazyVStack(spacing: 8) {
            if showingAddForm, let xcodeCommandIndex = userDefinedXcodeShortcuts.nextAvailableXcodeCommandIndex() {
              EditingShortcutRow(
                userDefinedXcodeShortcuts: $userDefinedXcodeShortcuts,
                editingShortcut: $editingShortcut,
                shortcut: UserDefinedXcodeShortcut(
                  name: "",
                  command: "",
                  xcodeCommandIndex: xcodeCommandIndex),
                isNew: true,
                onSave: { shortcut in
                  userDefinedXcodeShortcuts.append(shortcut)
                  showingAddForm = false
                },
                onCancel: {
                  showingAddForm = false
                })
            }

            ForEach(userDefinedXcodeShortcuts.indices, id: \.self) { index in
              let shortcut = userDefinedXcodeShortcuts[index]
              if editingShortcut?.id == shortcut.id {
                EditingShortcutRow(
                  userDefinedXcodeShortcuts: $userDefinedXcodeShortcuts,
                  editingShortcut: $editingShortcut,
                  shortcut: shortcut)
              } else {
                ShortcutRow(
                  userDefinedXcodeShortcuts: $userDefinedXcodeShortcuts,
                  editingShortcut: $editingShortcut,
                  shortcut: shortcut)
              }
            }

            if userDefinedXcodeShortcuts.isEmpty, !showingAddForm {
              Text("No user defined Xcode shortcuts configured")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
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
    .onReceive(permissionsService.status(for: .xcodeExtension)) { isGranted in
      isXcodeExtensionPermissionGranted = isGranted == true
    }
  }

  @State private var isXcodeExtensionPermissionGranted = false
  @State private var editingShortcut: UserDefinedXcodeShortcut?
  @State private var showingAddForm = false
  @Environment(\.colorScheme) private var colorScheme

  @Dependency(\.permissionsService) private var permissionsService

  private var hasAvailableCommandIndex: Bool {
    userDefinedXcodeShortcuts.nextAvailableXcodeCommandIndex() != nil
  }

  private func envVarRow(_ name: String, _ description: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("$\(name)")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.primary)
          .textSelection(.enabled)
        Spacer(minLength: 0)
      }
      Text(description)
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
}

// MARK: - ShortcutRow

struct ShortcutRow: View {
  @State private var errorMessage: String?

  @Binding var userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut]
  @Binding var editingShortcut: UserDefinedXcodeShortcut?
  let shortcut: UserDefinedXcodeShortcut

  @Dependency(\.xcodeObserver) private var xcodeObserver
  @Dependency(\.shellService) private var shellService
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(shortcut.name)
            .font(.body)
            .fontWeight(.medium)
            .textSelection(.enabled)

          Spacer()

          HStack(spacing: 4) {
            HoveredButton(
              action: {
                Task {
                  do {
                    errorMessage = nil
                    let input = UserDefinedXcodeShortcutExecutionInput(
                      shortcutId: "\(shortcut.xcodeCommandIndex)",
                      shellCommand: shortcut.command)
                    try await input.execute(xcodeObserver: xcodeObserver, shellService: shellService)
                  } catch {
                    errorMessage = error.localizedDescription
                  }
                }
              },
              onHoverColor: colorScheme.secondarySystemBackground,
              padding: 6,
              cornerRadius: 6)
            {
              Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .medium))
            }

            HoveredButton(
              action: {
                editingShortcut = shortcut
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

        Text(shortcut.command)
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)

        if let keyBinding = shortcut.keyBinding {
          HStack {
            Text("Key Binding:")
              .font(.subheadline)

            Text(keyBinding.display)
              .font(.system(.body, design: .monospaced))
              .foregroundColor(.secondary)
          }
        }

        if let errorMessage {
          Text("Error: \(errorMessage)")
            .font(.caption)
            .foregroundColor(colorScheme.redError)
        }
      }
    }
    .padding(12)
    .background(Color.gray.opacity(0.05))
    .cornerRadius(8)
  }
}

// MARK: - EditingShortcutRow

struct EditingShortcutRow: View {
  init(
    userDefinedXcodeShortcuts: Binding<[UserDefinedXcodeShortcut]>,
    editingShortcut: Binding<UserDefinedXcodeShortcut?>,
    shortcut: UserDefinedXcodeShortcut,
    isNew: Bool = false,
    onSave: ((UserDefinedXcodeShortcut) -> Void)? = nil,
    onCancel: (() -> Void)? = nil)
  {
    _userDefinedXcodeShortcuts = userDefinedXcodeShortcuts
    _editingShortcut = editingShortcut
    self.shortcut = shortcut
    self.isNew = isNew
    self.onSave = onSave
    self.onCancel = onCancel
    _editingName = State(initialValue: shortcut.name)
    _editingCommand = State(initialValue: shortcut.command)
  }

  @Binding var userDefinedXcodeShortcuts: [UserDefinedXcodeShortcut]
  @Binding var editingShortcut: UserDefinedXcodeShortcut?

  let shortcut: UserDefinedXcodeShortcut
  let isNew: Bool
  let onSave: ((UserDefinedXcodeShortcut) -> Void)?
  let onCancel: (() -> Void)?

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Name")
              .font(.caption)
              .foregroundColor(.secondary)
            TextField("Open file in GitHub", text: $editingName)
              .textFieldStyle(.roundedBorder)
          }

          Spacer()

          HStack(alignment: .top, spacing: 4) {
            HoveredButton(
              action: {
                let updatedShortcut = UserDefinedXcodeShortcut(
                  id: isNew ? UUID() : shortcut.id,
                  name: editingName,
                  command: editingCommand,
                  keyBinding: shortcut.keyBinding,
                  xcodeCommandIndex: shortcut.xcodeCommandIndex)

                if isNew {
                  onSave?(updatedShortcut)
                } else {
                  if let index = userDefinedXcodeShortcuts.firstIndex(where: { $0.id == shortcut.id }) {
                    userDefinedXcodeShortcuts[index] = updatedShortcut
                  }
                  editingShortcut = nil
                }
              },
              onHoverColor: colorScheme.secondarySystemBackground,
              padding: 6,
              cornerRadius: 6)
            {
              Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .medium))
            }
            .disabled(editingName.isEmpty || editingCommand.isEmpty)

            HoveredButton(
              action: {
                if isNew {
                  onCancel?()
                } else {
                  editingShortcut = nil
                }
              },
              onHoverColor: colorScheme.secondarySystemBackground,
              padding: 6,
              cornerRadius: 6)
            {
              Image(systemName: "xmark")
                .font(.system(size: 12, weight: .medium))
            }
          }
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Shell Command")
            .font(.caption)
            .foregroundColor(.secondary)
          TextField("open \"https://github.com/myorg/myrepo/$FILEPATH_FROM_GIT_ROOT\"", text: $editingCommand)
            .textFieldStyle(.roundedBorder)
        }

        if !isNew {
          Text("This will be mapped to Xcode command index \(shortcut.xcodeCommandIndex)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(12)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
  }

  @State private var editingName: String
  @State private var editingCommand: String

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
