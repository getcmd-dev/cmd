// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import Foundation
import SwiftUI
import XcodeObserverServiceInterface
import XcodeObserverWindowsAdapter

final class InlineChatWindow: XcodeWindow {
  init() {
    let viewModel = InlineChatsViewModel()
    self.viewModel = viewModel

    super.init(contentRect: .zero)

    styleMask = [.borderless]
    hasShadow = false
    isOpaque = false
    ignoresMouseEvents = false // TODO: deal with only getting mouse events over the chat UI

    collectionBehavior = [
      .fullScreenAuxiliary,
      .fullScreenPrimary,
      .fullScreenAllowsTiling,
    ]
    makeKeyAndOrderFront(nil)

    backgroundColor = .clear

    let root = AnyView(InlineChatView(viewModel: viewModel))
      .background(.clear)

    let hostingView = NSHostingView(rootView: root)

    hostingView.wantsLayer = true
    hostingView.layer?.masksToBounds = true
    contentView = hostingView
  }

  override func getFrame() -> CGRect? {
    guard let chat = viewModel.inlineChat else {
      setIsVisible(false)
      return nil
    }
    if chat.id != chatId {
      chatId = chat.id
    }
    guard
      let editor = xcodeObserver.state.focussedEditor,
      let editorFrame = editor.axElement.appKitFrame,
      let scrollViewFrame = editor.axElement.wrappedValue?.parent?.appKitFrame
    else {
      return nil
    }
    setIsVisible(true)

    updateViewModel(editor: editor, editorFrame: editorFrame, scrollViewFrame: scrollViewFrame, chat: chat)

    return editorFrame.intersection(scrollViewFrame)
  }

  private var leadingEditorOffset: CGFloat?
  private var trailingEditorOffset: CGFloat?

  private var chatId: UUID?

  private var location: Int?

  private let viewModel: InlineChatsViewModel

  private func updateViewModel(
    editor: XcodeEditorState,
    editorFrame: CGRect,
    scrollViewFrame _: CGRect,
    chat: InlineChatViewModel)
  {
    if chat.id != chatId || location == nil {
      chatId = chat.id
      // Cache `location` as this requires counting characters throughout the completed file
      // which is somewhat resource intensive.
      location = chat.content.location(of: .init(line: chat.selection.start.line, character: chat.selection.start.character))
      // TODO: handle when the content of the file change afte the inline chat is created.
    }
    guard
      let location,
      let completedTextFrame = editor.axElement.getTextFrame(range: .init(location: location, length: 0))?.invertedFrame
    else {
      return
    }
    let lineHeight = completedTextFrame.height // TODO: deal with line wapping.

    // Leading offset between editor frame and text area frame
    if
      leadingEditorOffset == nil || viewModel.lineHeight != lineHeight,
      let range = chat.content.nsRange(of:
        .init(
          start: .init(line: chat.selection.start.line, character: 0),
          end: .init(line: chat.selection.start.line, character: 0))),
      let baseline = editor.axElement.getTextFrame(range: range)?.invertedFrame
    {
      let leadingOffset = baseline.minX - editorFrame.minX
      if leadingOffset != 0 {
        viewModel.leadingContentOffset = leadingOffset
        leadingEditorOffset = leadingOffset
      }
    }
    // Trailing offset between editor frame and text area frame
    if
      trailingEditorOffset == nil || viewModel.lineHeight != lineHeight,
      let range = chat.content.nsRange(of:
        .init(
          start: .init(line: chat.selection.start.line, character: 0),
          end: .init(line: chat.selection.start.line + 1, character: 0))),
      let baseline = editor.axElement.getTextFrame(range: range)?.invertedFrame
    {
      let trailingOffset = editorFrame.maxX - baseline.maxX
      if trailingOffset != 0, trailingOffset < 100 {
        viewModel.trailingContentOffset = trailingOffset
        trailingEditorOffset = trailingOffset
      }
    }

    // TODO: avoid setting if unchanged
    viewModel.lineHeight = lineHeight
    viewModel.verticalContentOffset = frame.maxY - completedTextFrame.maxY
  }

}
