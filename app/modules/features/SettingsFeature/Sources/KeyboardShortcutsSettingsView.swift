// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import DLS
import SettingsServiceInterface
import SwiftUI

// MARK: - KeyboardShortcutsView

typealias KeyboardShortcuts = SettingsServiceInterface.Settings.KeyboardShortcuts
typealias KeyboardShortcut = SettingsServiceInterface.Settings.KeyboardShortcut

// MARK: - KeyboardShortcutsSettingsView

struct KeyboardShortcutsSettingsView: View {
  init(keyboardShortcuts: Binding<KeyboardShortcuts>) {
    _keyboardShortcuts = keyboardShortcuts
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      KeyboardShortcutView(
        title: "Add to current chat",
        description: "Continue existing conversation with added context",
        defaultValue: Settings.KeyboardShortcutKey.addContextToCurrentChat.defaultShortcut,
        keyboardShortcut: $keyboardShortcuts[.addContextToCurrentChat])
      KeyboardShortcutView(
        title: "Add to new chat",
        description: "Create a new conversation with the selected context",
        defaultValue: Settings.KeyboardShortcutKey.addContextToNewChat.defaultShortcut,
        keyboardShortcut: $keyboardShortcuts[.addContextToNewChat])
      KeyboardShortcutView(
        title: "Dismiss",
        description: "Dismiss cmd. It'll still be available in the menu bar and respond to shortcuts",
        defaultValue: Settings.KeyboardShortcutKey.dismissChat.defaultShortcut,
        keyboardShortcut: $keyboardShortcuts[.dismissChat])
      Spacer()
    }
  }

  @Binding private var keyboardShortcuts: KeyboardShortcuts

}

// MARK: - KeyboardShortcutView

struct KeyboardShortcutView: View {
  init(
    title: String,
    description: String? = nil,
    defaultValue: KeyboardShortcut,
    keyboardShortcut: Binding<KeyboardShortcut?>)
  {
    _keyboardShortcut = keyboardShortcut
    self.title = title
    self.description = description
    self.defaultValue = defaultValue

    let initialShortcut = keyboardShortcut.wrappedValue ?? defaultValue
    _inputShortcut = .init(initialValue: .init(string: display(shortcut: initialShortcut)))
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack(spacing: 0) {
        Text(title + ":")
          .padding(.trailing, 8)

        RichTextEditor(
          text: $inputShortcut,
          onKeyDown: { key, modifiers in
            if !modifiers.isEmpty {
              let shortcut = KeyboardShortcut(key: key, modifiers: modifiers)
              inputShortcut = .init(string: display(shortcut: shortcut))
              keyboardShortcut = shortcut
            }
            return true
          })
          .frame(width: 60, height: Constants.lineHeight)
          .with(
            cornerRadius: 5,
            backgroundColor: colorScheme.tertiarySystemBackground,
            borderColor: colorScheme.textAreaBorderColor,
            borderWidth: 0.5)

        Spacer(minLength: 0)

        if keyboardShortcut != nil, keyboardShortcut != defaultValue {
          HoveredButton(
            action: {
              keyboardShortcut = nil
            },
            onHoverColor: colorScheme.tertiarySystemBackground,
            backgroundColor: colorScheme.secondarySystemBackground,
            padding: 5,
            content: {
              Text("Reset to \(display(shortcut: defaultValue))")
            })
            .frame(height: Constants.lineHeight)
        }
      }
      if let description {
        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .onChange(of: keyboardShortcut) {
      inputShortcut = .init(string: display(shortcut: keyboardShortcut ?? defaultValue))
    }
  }

  func display(shortcut: KeyboardShortcut) -> String {
    (
      shortcut.modifiers
        .map(\.description)
        + [shortcut.key.description])
      .joined(separator: " ")
  }

  private enum Constants {
    static let lineHeight: CGFloat = 20
  }

  @Binding private var keyboardShortcut: KeyboardShortcut?
  @State private var inputShortcut = NSAttributedString("")

  @Environment(\.colorScheme) private var colorScheme

  private let title: String
  private let description: String?
  private let defaultValue: KeyboardShortcut

}
