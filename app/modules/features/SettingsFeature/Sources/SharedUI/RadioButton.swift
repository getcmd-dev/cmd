// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import SwiftUI

struct RadioButton: NSViewRepresentable {
  class Coordinator: NSObject {
    init(action: @escaping () -> Void) {
      self.action = action
    }

    let action: () -> Void

    @objc
    func buttonTapped() {
      action()
    }
  }

  let isSelected: Bool
  let action: () -> Void

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton(radioButtonWithTitle: "", target: context.coordinator, action: #selector(Coordinator.buttonTapped))
    button.state = isSelected ? .on : .off
    return button
  }

  func updateNSView(_ nsView: NSButton, context _: Context) {
    nsView.state = isSelected ? .on : .off
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(action: action)
  }

}
