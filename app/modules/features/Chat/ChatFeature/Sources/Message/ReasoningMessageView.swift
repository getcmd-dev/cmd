// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import Markdown
import SwiftUI

struct ReasoningMessageView: View {
  let reasoning: ChatMessageReasoningContent

  var body: some View {
    VStack(alignment: .leading) {
//      Button(action: {
//        isExpanded.toggle()
//      }) {
//        HStack(spacing: 0) {
//          Icon(systemName: iconName(isHovered: isHovered))
//            .frame(square: iconSize(isHovered: isHovered))
//            .padding(.trailing, 8)
//            .frame(width: 24)
//          Text(thinkingDescription)
//          if reasoning.isStreaming {
//            ThreeDotsLoadingAnimation()
//          }
//        }
//        .onHover { isHovered in
//          self.isHovered = isHovered
//        }
//        .foregroundColor(isHovered ? colorScheme.primaryForeground : colorScheme.secondaryForeground)
//        .tappableTransparentBackground()
//      }
//      .buttonStyle(.plain)
//      if isExpanded {
        Text(plainTextContent)
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(.secondary)
//          .padding(.leading)
//      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  @State private var isExpanded = false

  @State private var isHovered = false

  /// Some providers, like Codex, will use markdown formating for reasoning.
  /// We remove it and display plain text.
  @MainActor
  private var plainTextContent: String {
    let attStr = colorScheme.markDownStyle
      .markdown(for: reasoning.text.trimmingCharacters(in: .whitespacesAndNewlines))
    return NSAttributedString(attStr).string
  }

  private var thinkingDescription: String {
    "Thinking"
  }

  private func iconName(isHovered: Bool) -> String {
    if reasoning.isStreaming {
      return "brain"
    }
    if isExpanded {
      return "chevron.down"
    }
    if isHovered {
      return "chevron.right"
    }
    return "brain"
  }

  private func iconSize(isHovered: Bool) -> CGFloat {
    iconName(isHovered: isHovered) == "brain" ? 16 : 8
  }

}
