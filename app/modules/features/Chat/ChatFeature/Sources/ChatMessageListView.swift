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
    ScrollView {
      AppUpdateWidget()
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
    }
  }

  private let events: [ChatEvent]
  private let onRestoreTapped: ((Checkpoint) -> Void)?
}
