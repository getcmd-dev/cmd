// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CheckpointServiceInterface
import DLS
import Foundation
import SwiftUI

// MARK: - ChatMessageList

struct ChatMessageList: View {
  #if DEBUG
  /// Initializer for previews
  init(
    events: [ChatEvent],
    onRestoreTapped: ((Checkpoint) -> Void)? = nil)
  {
    self.events = events
    self.onRestoreTapped = onRestoreTapped
  }
  #endif

  init(viewModel: ChatThreadViewModel) {
    events = viewModel.events
    onRestoreTapped = { [weak viewModel] checkpoint in
      viewModel?.handleRestore(checkpoint: checkpoint)
    }
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        AppUpdateWidget()
        if events.count == 0 {
          EmptyChatView()
            .padding(ChatView.Constants.chatPadding)
        }
        LazyVStack(spacing: 0) {
          ForEach(events) { event in
            switch event {
            case .message(let message):
              ChatMessageView(message: message)
                .padding(.horizontal, ChatView.Constants.chatPadding)
                .padding(.top, 2)

            case .checkpoint(let checkpoint):
              CheckpointView(checkpoint: checkpoint, onRestoreTapped: onRestoreTapped)
            }
          }
        }
        .padding(.vertical, ChatView.Constants.chatPadding)
        .id(Constants.scrollAnchorID)
        .background(GeometryReader {
          let frame = $0.frame(in: .named(Constants.scrollCoordinateSpace))
          Task { @MainActor in
            if !isUserScrolling {
              scrollToBottomIfNeeded(proxy: proxy)
            } else {
              let offset = -frame.origin.y
              contentIsScrolledDown = frame.height - offset - scrollViewHeight < 25
            }
          }
          return Color.clear
        })
      }
      .coordinateSpace(name: Constants.scrollCoordinateSpace)
      .onScrollPhaseChange { _, new in
        if new == .interacting {
          isUserScrolling = true
        }
        if new == .decelerating {
          isUserScrolling = false
          contentWasScrolledDownByUser = contentIsScrolledDown
        }
        if new == .idle {
          contentWasScrolledDownByUser = contentIsScrolledDown
        }
      }
      .onAppear {
        scrollToBottomIfNeeded(proxy: proxy)
      }
      .readingSize { scrollViewSize in
        scrollViewHeight = scrollViewSize.height
      }
    }
  }

  private enum Constants {
    static let scrollAnchorID = "anchor"
    static let scrollCoordinateSpace = "scroll"
  }

  @State private var scrollViewHeight: CGFloat = 0
  @State private var contentIsScrolledDown = true
  @State private var contentWasScrolledDownByUser = true
  @State private var isUserScrolling = false

  private let events: [ChatEvent]
  private let onRestoreTapped: ((Checkpoint) -> Void)?

  private func scrollToBottomIfNeeded(proxy: ScrollViewProxy) {
    guard contentWasScrolledDownByUser else { return }
    proxy.scrollTo(Constants.scrollAnchorID, anchor: .bottom)
  }

}
