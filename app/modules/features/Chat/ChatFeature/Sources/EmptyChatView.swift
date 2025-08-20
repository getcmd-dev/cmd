// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - EmptyChatView

struct EmptyChatView: View {
  var body: some View {
    VStack {
      Text("Keyboard Shortcuts")
        .padding(4)
      Text("Get started quickly with these helpful commands")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.bottom, 4)
      keyBoardShortCutCard(
        title: "Add to current chat",
        description: "Continue exisiting conversation with added context",
        keys: ["⌘", "I"])
      keyBoardShortCutCard(
        title: "Add to new chat",
        description: "Created a new conversation with the selected context",
        keys: ["⌘", "↑", "I"])
      keyBoardShortCutCard(
        title: "Dismiss",
        description: "Dismiss command. It'll still be available in the menu bar and respond to shortcuts",
        keys: ["⌘", "␛"])
      keyBoardShortCutCard(title: "Cycle chat mode", description: "Switch between different chat mode", keys: ["⇧", "⇥"])
    }
  }

  @ViewBuilder
  func keyBoardShortCutCard(title: String, description: String, keys: [String]) -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text(title)
        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Spacer(minLength: 10)
      HStack(spacing: 0) {
        ForEach(Array(keys.enumerated()), id: \.element) { idx, key in
          Text(key)
            .font(.system(size: 12, design: .monospaced))
            .frame(square: 12)
            .padding(4)
            .with(
              cornerRadius: 4,
              backgroundColor: .gray.opacity(0.1),
              borderColor: colorScheme.textAreaBorderColor,
              borderWidth: 0.5)
          if idx != keys.count - 1 {
            Text("+")
              .padding(.horizontal, 4)
          }
        }
      }
    }
    .padding(8)
    .with(
      cornerRadius: 4,
      backgroundColor: .gray.opacity(0.02),
      borderColor: colorScheme.textAreaBorderColor,
      borderWidth: 0.5)
  }

  @Environment(\.colorScheme) private var colorScheme
}
