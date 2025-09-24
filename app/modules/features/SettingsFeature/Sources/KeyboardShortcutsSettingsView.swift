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
    _inputShortcut = .init(initialValue: .init(string: initialShortcut.display))
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack(spacing: 0) {
        Text(title + ":")
          .padding(.trailing, 8)

        KeyBindingInputView(keyboardShortcut: $keyboardShortcut, lineHeight: Constants.lineHeight)

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
              Text("Reset to \(defaultValue.display)")
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
      inputShortcut = .init(string: (keyboardShortcut ?? defaultValue).display)
    }
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

extension KeyboardShortcut {
  /// A string representation of the key binding.
  var display: String {
    (
      modifiers
        .map(\.description)
        + [key.description])
      .joined(separator: " ")
  }
}

// MARK: - KeyBindingInputView

struct KeyBindingInputView: View {
  init(keyboardShortcut: Binding<KeyboardShortcut?>, lineHeight: CGFloat = 20) {
    _keyboardShortcut = keyboardShortcut
    self.lineHeight = lineHeight
    _inputShortcut = .init(initialValue: NSAttributedString(string: keyboardShortcut.wrappedValue?.display ?? ""))
  }

  var body: some View {
    RichTextEditor(
      text: $inputShortcut,
      onKeyDown: { key, modifiers in
        if !modifiers.isEmpty {
          let shortcut = KeyboardShortcut(key: key, modifiers: modifiers)
          inputShortcut = .init(string: shortcut.display)
          keyboardShortcut = shortcut
        } else if key == .delete {
          inputShortcut = NSAttributedString(string: "")
          keyboardShortcut = nil
        }
        return true
      })
      .frame(width: 60, height: lineHeight)
      .with(
        cornerRadius: 5,
        backgroundColor: colorScheme.tertiarySystemBackground,
        borderColor: colorScheme.textAreaBorderColor,
        borderWidth: 0.5)
      .onChange(of: keyboardShortcut) { newValue in
        inputShortcut = NSAttributedString(string: newValue?.display ?? "")
      }
  }

  @State private var inputShortcut: NSAttributedString
  @Binding private var keyboardShortcut: KeyboardShortcut?
  @Environment(\.colorScheme) private var colorScheme

  private let lineHeight: CGFloat

}
