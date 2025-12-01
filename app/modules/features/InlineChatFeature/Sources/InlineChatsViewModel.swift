// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import ChatAppEventsFoundation
import Combine
import Dependencies
import Foundation
import LoggingServiceInterface
import Observation
import XcodeObserverServiceInterface

@Observable @MainActor
final class InlineChatsViewModel {
  init() {
    @Dependency(\.xcodeObserver) var xcodeObserver
    self.xcodeObserver = xcodeObserver
    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry

    appEventHandlerRegistry.registerHandler { [weak self] event in
      guard let self else { return false }
      switch event {
      case is EditCodeInlineEvent:
        Task {
          await self.addNewChat()
        }
        return true

      default:
        return false
      }
    }

    xcodeObserver.statePublisher.sink { [weak self] state in
      Task { await self?.update(inlineChatsFor: state) }
    }.store(in: &cancellables)
  }

  /// Workspace URL -> File URL -> InlineChats
  var chats = [URL: [URL: [InlineChatViewModel]]]()

  var verticalContentOffset: CGFloat = 0
  /// The leading offset between the editor and the text area frames.
  var leadingContentOffset: CGFloat = 0
  /// The trailing offset between the editor and the text area frames.
  var trailingContentOffset: CGFloat = 0
  var lineHeight: CGFloat?

  /// The inline chats that are visible in the current editor.
  var inlineChat: InlineChatViewModel? { inlineChats.last }

  func closeChat(_ chat: InlineChatViewModel) {
    chats[chat.workspace]?[chat.file]?.removeAll { $0.id == chat.id }
    inlineChats = inlineChats.filter { $0.id != chat.id }
  }

  private var inlineChats = [InlineChatViewModel]()

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  private let xcodeObserver: XcodeObserver

  private func update(inlineChatsFor state: AXState<XcodeState>) async {
    guard
      let workspace = state.focusedWorkspace,
      let file = await xcodeObserver.focusedTabURL(in: workspace)
    else {
      inlineChats = []
      return
    }
    inlineChats = chats[workspace.url]?[file] ?? []
  }

  private func addNewChat() async {
    defaultLogger.trace("Adding new inline chat")
    guard
      let workspace = xcodeObserver.state.focusedWorkspace,
      let editor = workspace.focussedEditor,
      let file = await xcodeObserver.focusedTabURL(in: workspace),
      let selection = editor.selections.first
    else {
      defaultLogger.trace("not ading new inline chat")
      return
    }

    if chats[workspace.url] == nil {
      chats[workspace.url] = [:]
    }
    if chats[workspace.url]?[file] == nil {
      chats[workspace.url]?[file] = []
    }
    let newChat = InlineChatViewModel(
      workspace: workspace.url,
      file: file,
      selection: selection,
      content: editor.content)
    defaultLogger.trace("Addint inline chat at line: \(selection.start.line)")
    chats[workspace.url]?[file]?.append(newChat)

    await update(inlineChatsFor: xcodeObserver.state)
  }

}
