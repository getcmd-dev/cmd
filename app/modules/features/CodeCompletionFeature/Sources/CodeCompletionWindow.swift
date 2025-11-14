// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AccessibilityObjCFoundation
import AppKit
import ConcurrencyFoundation
import Dependencies
import DLS
import FoundationInterfaces
import LoggingServiceInterface
import RoutingFoundation
import SettingsServiceInterface
import SwiftUI
import XcodeObserverServiceInterface
import XcodeObserverWindowsAdapter

// MARK: - CodeCompletionWindow

/// A side panel displayed on the side of Xcode.
final class CodeCompletionWindow: XcodeWindow {

  init() {
    let needsLayout = Atomic<@Sendable @MainActor () -> Void>({ })
    let screenshotEditor = Atomic<@Sendable @MainActor () async throws -> CGImage?>({ nil })
    viewModel = CodeCompletionViewModel(
      needsLayout: { needsLayout.value() },
      screenshotEditor: { try await screenshotEditor.value() })
    super.init(contentRect: .zero)

    needsLayout.set(to: { [weak self] in
      self?.show()
    })
    screenshotEditor.set(to: { [weak self] in
      try await self?.screenshotEditor()
    })
    let colorSpace = screen?.colorSpace ?? .sRGB
    viewModel.colorSpace = colorSpace

    styleMask = [.borderless]
    hasShadow = false
    isOpaque = false
    ignoresMouseEvents = true

    collectionBehavior = [
      .fullScreenAuxiliary,
      .fullScreenPrimary,
      .fullScreenAllowsTiling,
    ]
    makeKeyAndOrderFront(nil)

    backgroundColor = .clear

    let root = AnyView(CodeCompletionView(viewModel: viewModel))
      .background(.clear)

    let hostingView = NSHostingView(rootView: root)
    self.hostingView = hostingView

    hostingView.wantsLayer = true
    hostingView.layer?.masksToBounds = true
    contentView = hostingView
  }

  override var canBecomeKey: Bool { false }
  override var acceptsFirstResponder: Bool { false }

  var defaultWidth: CGFloat { 400 }

  override func getFrame() -> CGRect? {
    guard
      let editor = xcodeObserver.state.focussedEditor,
      let editorFrame = editor.axElement.appKitFrame,
      let scrollViewFrame = editor.axElement.wrappedValue?.parent?.appKitFrame
    else {
      if xcodeObserver.state.focussedEditor?.axElement.wrappedValue?.isValid == false {
        defaultLogger.log("Skipping completion window frame update as focussed editor is invalid")
      }
      return nil
    }
    if viewModel.completion != nil, let completionTask = viewModel.completionTask {
      updateViewModel(editor: editor, editorFrame: editorFrame, scrollViewFrame: scrollViewFrame, completionTask: completionTask)
    } else {
      completionId = nil
      completionRange = nil
    }

    // Measure line height from selection frame
    return editorFrame.intersection(scrollViewFrame)
  }

  private var completionId: UUID?
  private var completionRange: NSRange?
  /// The offset be
  private var leadingEditorOffset: CGFloat?
  private var trailingEditorOffset: CGFloat?

  private let viewModel: CodeCompletionViewModel

  private var hostingView: NSView?

  private func updateViewModel(
    editor: XcodeEditorState,
    editorFrame: CGRect,
    scrollViewFrame _: CGRect,
    completionTask: CompletionTask)
  {
    if completionTask.id != completionId || completionRange == nil {
      completionId = completionTask.id
      // Cache `completionRange` as this requires counting characters throughout the completed file
      // which is somewhat resource intensive.
      completionRange = completionTask.request.content.nsRange(of: completionTask.request.selection)
    }
    guard
      let completionRange,
      let completedTextFrame = editor.axElement.getTextFrame(range: completionRange)?.invertedFrame
    else {
      return
    }
    let request = completionTask.request
    let lineHeight = completedTextFrame.height / CGFloat(request.selection.end.line - request.selection.start.line + 1)

    // Leading offset between editor frame and text area frame
    if
      leadingEditorOffset == nil || viewModel.lineHeight != lineHeight,
      let range = request.content.nsRange(of:
        .init(
          start: .init(line: request.selection.start.line, character: 0),
          end: .init(line: request.selection.start.line, character: 0))),
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
      let range = request.content.nsRange(of:
        .init(
          start: .init(line: request.selection.start.line, character: 0),
          end: .init(line: request.selection.start.line + 1, character: 0))),
      let baseline = editor.axElement.getTextFrame(range: range)?.invertedFrame
    {
      let trailingOffset = editorFrame.maxX - baseline.maxX
      if trailingOffset != 0, trailingOffset < 100 {
        viewModel.trailingContentOffset = trailingOffset
        trailingEditorOffset = trailingOffset
      }
    }

    if
      viewModel.lineHeight != lineHeight,
      let (content, size) = request.content.contentToInferFontSize(around: request.selection, in: editor.axElement)
    {
      viewModel.lineHeight = size.height
      viewModel.updateFont(
        toMatch: size.width,
        for: content)
    }
    viewModel.verticalContentOffset = frame.maxY - completedTextFrame.maxY
  }

  private func screenshotEditor() async throws -> CGImage? {
    guard
      let completionRange,
      let editor = xcodeObserver.state.focussedEditor,
      let completedTextFrame = editor.axElement.getTextFrame(range: completionRange)?.invertedFrame,
      let editorFrame = editor.axElement.appKitFrame,
      let scrollViewFrame = editor.axElement.wrappedValue?.parent?.appKitFrame,
      let windowId = trackedWindowNumber,
      let windowTop = trackedWindow?.cgFrame?.minY
    else {
      return nil
    }
    if completedTextFrame.minY - scrollViewFrame.maxY > -10 || completedTextFrame.maxY - scrollViewFrame.minY < 10 {
      // Completed text is out of view
      return nil
    }

    var frame = editorFrame.intersection(scrollViewFrame)
    frame = CGRect(
      origin: frame.origin,
      size: .init(
        width: frame.width - (trailingEditorOffset ?? 0) - 2,
        height: abs(frame.minY - completedTextFrame.minY))) // -2 to not overlap with scroll position
      .intersection(scrollViewFrame)
    guard var frame = frame.invertedFrame else {
      return nil
    }
    frame = frame.insetBy(dx: 0, dy: -windowTop)
    return try await XcodeScreenshoter.screenshot(
      windowId: windowId,
      frame: frame)
  }

}
