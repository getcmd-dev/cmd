// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AccessibilityObjCFoundation
import AppKit
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
    viewModel = CodeCompletionViewModel()
    super.init(contentRect: .zero)

    styleMask = [.borderless]
    hasShadow = false
    isOpaque = false
    ignoresMouseEvents = true

    collectionBehavior = [
      .fullScreenAuxiliary,
      .fullScreenPrimary,
      .fullScreenAllowsTiling,
    ]

//      let idealFrame = trackedWindow.map { self.frame(from: $0) } ?? nil
//      let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 300, height: 100))

//      let frame = idealFrame ?? defaultFrame
//      setFrame(frame, display: isVisible)
    makeKeyAndOrderFront(nil)
//      lastWindowFrame = frame

    backgroundColor = .clear

    let root = AnyView(CodeCompletionView(viewModel: viewModel))
      .background(.clear)

    let hostingView = NSHostingView(rootView: root)
    self.hostingView = hostingView

    hostingView.translatesAutoresizingMaskIntoConstraints = false
    contentView = hostingView

    // Observe size changes and update window frame
//    setupSizeObserver()
  }

  var completionId: UUID?
  var completionRange: NSRange?
  var leadingMargingWidth: CGFloat?

//    func addTwoNumbers(_ a: Int, _ b: Int) -> Int {
//        return a + b
//    }

//  @MainActor
//  deinit {
//    sizeObservationTimer?.invalidate()
//  }

  ///
  override var canBecomeKey: Bool { false }

  override var acceptsFirstResponder: Bool { false }

  var defaultWidth: CGFloat { 400 }

  override func getFrame() -> CGRect? {
    guard viewModel.completion != nil, let completionTask = viewModel.completionTask else {
      completionId = nil
      completionRange = nil
      return nil
    }
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
    if completionTask.id != completionId || completionRange == nil {
      completionId = completionTask.id
      // Cache `completionRange` as this requires counting characters throughout the completed file
      // which is somewhat resource intensive.
      completionRange = completionTask.request.content.nsRange(of: .init(
        start: .init(line: completionTask.request.selection.start.line, character: 0), // TODO: undo
        end: .init(line: completionTask.request.selection.end.line, character: completionTask.request.selection.end.character)))
    }
    guard
      let completionRange,
      let completedTextFrame = editor.axElement.getTextFrame(range: completionRange)?.invertedFrame
    else {
      return nil
    }
    let request = completionTask.request
    let lineHeight = completedTextFrame.height / CGFloat(request.selection.end.line - request.selection.start.line + 1)

    if
      leadingMargingWidth == nil || viewModel.lineHeight != lineHeight,
      let range = request.content.nsRange(of:
        .init(
          start: .init(line: request.selection.start.line, character: 0),
          end: .init(line: request.selection.start.line, character: 0))),
      let baseline = editor.axElement.getTextFrame(range: range)?.invertedFrame
    {
      let offset = baseline.minX - editorFrame.minX
      if offset != 0 {
        viewModel.horizontalContentOffset = offset
        leadingMargingWidth = offset
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

    // Measure line height from selection frame
    let frame = editorFrame.intersection(scrollViewFrame)
    viewModel.verticalContentOffset = frame.maxY - completedTextFrame.maxY
    return frame
  }

  private let viewModel: CodeCompletionViewModel

  private var hostingView: NSView?
}

// Repeat below: abcdefghijklmnopqrst
// abcd
