// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatInput
import DLS
import SwiftUI

struct InlineChatView: View {
  let viewModel: InlineChatsViewModel

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        if let chat = viewModel.inlineChat {
          Group {
            ChatInputView(
              inputViewModel: chat.input,
              config: ChatInputConfig(
                placeholderText: "Enter instructions",
                showChatMode: false,
                showAttachmentButton: false),
              contextControlsConfig: nil,
              isStreamingResponse: .constant(false))
              .overlay(alignment: .topTrailing) {
                IconButton(
                  action: {
                    viewModel.closeChat(chat)
                  },
                  systemName: "xmark",
                  padding: 2)
                  .frame(square: 10)
                  .padding(.top, 6)
                  .padding(.trailing, 6)
              }
          }
          .readingSize { contentSize in
            self.contentSize = contentSize
          }
          .padding(.leading, viewModel.leadingContentOffset + 1) // 1 to leave space for the cursor
          .padding(.trailing, viewModel.trailingContentOffset + 2) // 2 to not overlap with the scrollbar
          .frame(width: geometry.size.width)
          .fixedSize()
          .padding(.top, viewModel.verticalContentOffset - (contentSize?.height ?? 0))

        } else {
          // Empty state with minimal size
          Color.clear.frame(width: 1, height: 1)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
      .clipped()
      .border(.blue)
    }
  }

  @State private var contentSize: CGSize?
}
