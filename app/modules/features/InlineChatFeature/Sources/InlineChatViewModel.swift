// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatHistoryServiceInterface
import ChatInput
import Dependencies
import Foundation
import LLMFoundation
import Observation
import XcodeObserverServiceInterface

@Observable @MainActor
final class InlineChatViewModel {
  init(workspace: URL, file: URL, selection: CursorRange, content: String) {
    self.workspace = workspace
    self.file = file
    self.selection = selection
    self.content = content
    let input = ChatInputViewModel()
    self.input = input
    input.didTapSendMessage = { [weak self] text, attachments in
      self?.handleSendMessage(text: text.string.string, attachments: attachments)
    }
    input.didCancelMessage = { [weak self] _ in
      print("Cancelled message")
    }
  }

  let input: ChatInputViewModel
  let id = UUID()
  let workspace: URL
  let file: URL
  let selection: CursorRange
  var model: AIModel?
  let content: String

  private func handleSendMessage(text _: String, attachments _: [AttachmentModel]) { }

}
