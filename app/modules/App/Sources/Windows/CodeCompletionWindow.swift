// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AccessibilityObjCFoundation
import AppKit
import CodeCompletionFeature
import Dependencies
import DLS
import FoundationInterfaces
import LoggingServiceInterface
import RoutingFoundation
import SettingsServiceInterface
import SwiftUI
import XcodeObserverServiceInterface

/// A side panel displayed on the side of Xcode.
final class CodeCompletionWindow: XcodeWindow {
  init(windowsViewModel: WindowsViewModel) {
    self.windowsViewModel = windowsViewModel

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

    hostingView.translatesAutoresizingMaskIntoConstraints = false
    contentView = hostingView
  }

  override var canBecomeKey: Bool { false }

  override var acceptsFirstResponder: Bool { true }

  var defaultWidth: CGFloat { 400 }

  override func getFrame() -> CGRect? {
    guard let trackedWindow else { return nil }
    let frame = frame(from: trackedWindow)
    if frame == .zero {
      windowsViewModel.handle(.closeSidePanel)
    }
    if let frame {
      lastWindowFrame = frame
    }
    return frame
  }

  private var lastWindowFrame: CGRect?

  private let windowsViewModel: WindowsViewModel

  /// This
  @MainActor
  private func frame(from _: AnyAXUIElement) -> CGRect? {
    CGRect(origin: .zero, size: CGSize(width: 300, height: 100))
  }

}
