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

/// A side panel displayed on the side of Xcode.
final class CodeCompletionWindow: XcodeWindow {
  init() {
    super.init(contentRect: .zero)

    styleMask = [.borderless]
    hasShadow = false
    isOpaque = false

    collectionBehavior = [
      .fullScreenAuxiliary,
      .fullScreenPrimary,
      .fullScreenAllowsTiling,
    ]

    let idealFrame = trackedWindow.map { self.frame(from: $0) } ?? nil
    let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 300, height: 100))

    let frame = idealFrame ?? defaultFrame
    setFrame(frame, display: isVisible)
    makeKeyAndOrderFront(nil)
    lastWindowFrame = frame

    backgroundColor = .clear

    let root = CodeCompletionFeatureBuilder.build()
      .background(.background)

    let hostingView = NSHostingView(rootView: root)
    self.hostingView = hostingView

    hostingView.translatesAutoresizingMaskIntoConstraints = false
    contentView = hostingView

    // Observe size changes and update window frame
    setupSizeObserver()
  }

  @MainActor
  deinit {
    sizeObservationTimer?.invalidate()
  }

  override var canBecomeKey: Bool { false }

  override var acceptsFirstResponder: Bool { true }

  var defaultWidth: CGFloat { 400 }

  override func getFrame() -> CGRect? {
    guard let trackedWindow else { return nil }
    let frame = frame(from: trackedWindow)
    if let frame {
      lastWindowFrame = frame
    }
    return frame
  }

  private var hostingView: NSView?
  private var sizeObservationTimer: Timer?

  private var lastWindowFrame: CGRect?

  private func setupSizeObserver() {
    // Use a timer to periodically check and adjust the window size
    sizeObservationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.updateWindowSize()
      }
    }
  }

  @MainActor
  private func updateWindowSize() {
    guard let hostingView else { return }

    let fittingSize = hostingView.fittingSize
    let currentFrame = frame

    // Only update if size changed significantly (avoid tiny adjustments)
    if abs(fittingSize.width - currentFrame.width) > 1 || abs(fittingSize.height - currentFrame.height) > 1 {
      let newFrame = CGRect(
        origin: currentFrame.origin,
        size: fittingSize)
      setFrame(newFrame, display: true, animate: true)
    }
  }

  @MainActor
  private func frame(from _: AnyAXUIElement) -> CGRect? {
    CGRect(origin: .zero, size: CGSize(width: 300, height: 100))
  }

}
