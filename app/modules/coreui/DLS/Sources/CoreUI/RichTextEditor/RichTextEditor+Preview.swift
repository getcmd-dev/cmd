// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import SwiftUI

#if DEBUG
extension NSAttributedString: @unchecked @retroactive Sendable { }

private struct HelperView: View {

  init() {
    text = ObservableValue(NSAttributedString(string: "Hello World"))
  }

  @Bindable var text: ObservableValue<NSAttributedString>

  var onFocusChanged: (Bool) -> Void = { _ in }

  var body: some View {
    VStack {
      Button(action: {
        let newText = NSMutableAttributedString(attributedString: text.value)
        newText.append(NSAttributedString(string: "ref", attributes: [
          .backgroundColor: NSColor.blue,
          .lockedAttributes:
            [
              NSAttributedString.Key.foregroundColor,
              NSAttributedString.Key.backgroundColor,
            ],
          .textBlock: UUID().uuidString,
        ]))
        text.value = newText
      }, label: {
        Text("Add Reference")
      })
      RichTextEditor(
        text: $text.value,
        needsFocus: Binding.constant(false),
        onFocusChanged: onFocusChanged,
        placeholder: "Placeholder")
    }
    .frame(width: 200)
    .padding()
    .background(Color.gray.opacity(0.2))
  }
}

#Preview {
  HelperView()
}

#endif
