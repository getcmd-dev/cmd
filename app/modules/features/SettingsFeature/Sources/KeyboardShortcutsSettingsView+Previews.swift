// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SettingsServiceInterface
import SwiftUI

#if DEBUG

#Preview("Keyboard Shortcuts - Default") {
  KeyboardShortcutsSettingsView(keyboardShortcuts: .constant(SettingsServiceInterface.Settings.KeyboardShortcuts()))
    .frame(width: 600, height: 400)
    .padding()
}

#Preview("Keyboard Shortcuts - Custom") {
  KeyboardShortcutsSettingsView(keyboardShortcuts: .constant([
    .addContextToCurrentChat: .init(
      key: "k",
      modifiers: [.control]),
  ]))
  .frame(width: 600, height: 400)
  .padding()
}

#endif
