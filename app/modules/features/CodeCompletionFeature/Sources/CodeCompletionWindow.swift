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

  override var acceptsFirstResponder: Bool { true }

  var defaultWidth: CGFloat { 400 }

  override func getFrame() -> CGRect? {
    guard viewModel.completion != nil, let request = viewModel.completionTask?.request else {
      return nil
    }
    guard
      let editor = xcodeObserver.state.focusedWorkspace?.editors.first(where: { $0.isFocused }),
      let editorFrame = editor.axElement.appKitFrame,
      let scrollViewFrame = editor.axElement.wrappedValue?.parent?.appKitFrame,
      let lineFrame = getCompletedTextFrame()
    else {
      return nil
    }
    if
      leadingMargingWidth == nil,
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
    let frame = editorFrame.intersection(scrollViewFrame)

    viewModel.verticalContentOffset = frame.maxY - lineFrame.maxY
    return frame
  }

  ///
  func getCompletedTextFrame() -> CGRect? {
    guard let completionTask = viewModel.completionTask, let completion = viewModel.completion else {
      completionId = nil
      completionRange = nil
      return nil
    }
    if completionTask.id != completionId || completionRange == nil {
      completionId = completionTask.id
      completionRange = completionTask.request.content.nsRange(of: completionTask.request.selection)
    }
    guard
      let completionRange,
      let editor = xcodeObserver.state.focusedWorkspace?.editors.first(where: { $0.isFocused }),
      let selectionFrame = editor.axElement.getTextFrame(range: completionRange)?.invertedFrame
    else {
      return nil
    }

    return selectionFrame
  }

  private let viewModel: CodeCompletionViewModel
  //

  private var hostingView: NSView?
//  private var sizeObservationTimer: Timer?

//  private var lastWindowFrame: CGRect?

//  private func setupSizeObserver() {
//    // Use a timer to periodically check and adjust the window size
//    sizeObservationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
//      Task { @MainActor [weak self] in
//        self?.updateWindowSize()
//      }
//    }
//  }

//  @MainActor
//  private func updateWindowSize() {
//    guard let hostingView else { return }
//
//    let fittingSize = hostingView.fittingSize
//    let currentFrame = frame
//
//    // Only update if size changed significantly (avoid tiny adjustments)
//    if abs(fittingSize.width - currentFrame.width) > 1 || abs(fittingSize.height - currentFrame.height) > 1 {
//      let newFrame = CGRect(
//        origin: currentFrame.origin,
//        size: fittingSize)
//      setFrame(newFrame, display: true, animate: true)
//    }
//  }

//  @MainActor
//  private func frame(from _: AnyAXUIElement) -> CGRect? {
//    CGRect(origin: .zero, size: CGSize(width: 300, height: 100))
//  }

}

///
extension String {
  func nsRange(of range: CursorRange) -> NSRange? {
    var position = 0
    var length = 0
    for (idx, line) in split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
      if idx < range.start.line {
        position += line.count + 1 // +1 for the newline character
      }
      if idx == range.start.line {
        position += range.start.character
        length -= range.start.character
      }
      if idx < range.end.line {
        length += line.count + 1 // +1 for the newline character
      }
      if idx == range.end.line {
        length += range.end.character
        return NSRange(location: position, length: length)
      }
    }
    return nil
  }
}
