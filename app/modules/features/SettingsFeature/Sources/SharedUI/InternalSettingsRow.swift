// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
// MARK: - InternalSettingsRow

struct InternalSettingsRow: View {
  init(_ text: String, caption: String? = nil, value: Binding<Bool>) {
    self.text = text
    self.caption = caption
    _value = value
  }

  @Binding var value: Bool

  let text: String
  let caption: String?

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(text)
        if let caption {
          Text(caption)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Spacer()
      Toggle("", isOn: $value)
        .toggleStyle(.switch)
    }
  }
}
