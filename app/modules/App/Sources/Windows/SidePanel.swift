// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AccessibilityObjCFoundation
import AppKit
import ChatFeature
import Dependencies
import FoundationInterfaces
import LoggingServiceInterface
import SettingsFeature
import SettingsServiceInterface
import SwiftUI
import XcodeObserverServiceInterface

/// A side panel displayed on the side of Xcode.
final class SidePanel: XcodeWindow {
  init(windowsViewModel: WindowsViewModel) {
    self.windowsViewModel = windowsViewModel

    @Dependency(\.userDefaults) var userDefaults
    defaultChatPositionIsInverted = userDefaults.bool(forKey: .defaultChatPositionIsInverted)

    super.init(contentRect: .zero)

    styleMask = [.closable, .miniaturizable, .resizable, .titled]
    hasShadow = false

    // Configure title bar with solid background and fixed height
    titlebarAppearsTransparent = false
    titleVisibility = .hidden

    // Create and configure toolbar for fixed height
    let toolbar = NSToolbar(identifier: "SidePanelToolbar")
    toolbar.displayMode = .iconOnly
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    self.toolbar = toolbar

    collectionBehavior = [
      .fullScreenAuxiliary,
      .fullScreenPrimary,
      .fullScreenAllowsTiling,
    ]

    let idealFrame = trackedWindow.map { self.frame(from: $0) } ?? nil
    let screen = NSScreen.screens.first?.frame
    let defaultFrame = defaultChatPositionIsInverted
      ? CGRect(x: 0, y: 0, width: defaultWidth, height: screen?.size.height ?? 1000)
      : CGRect(
        x: (screen?.size.width ?? defaultWidth) - defaultWidth,
        y: 0,
        width: defaultWidth,
        height: screen?.size.height ?? 1000)

    let frame = idealFrame ?? defaultFrame
    setFrame(frame, display: isVisible)
    makeKeyAndOrderFront(nil)
    lastWindowFrame = frame

    backgroundColor = .clear

    let root = ChatView(
      viewModel: windowsViewModel.chat,
      SettingsView: { onDismiss in
        AnyView(SettingsView(
          viewModel: SettingsViewModel(),
          onDismiss: onDismiss))
      })
      .frame(maxWidth: .infinity, maxHeight: .infinity)

    let hostingView = NSHostingView(rootView: root)

    hostingView.translatesAutoresizingMaskIntoConstraints = false
    contentView = hostingView

    if let contentView {
      // Add custom border to contentView, useful to highlight the sides of the windows as we are not drawing the shadow.
      contentView.wantsLayer = true
      contentView.layer?.borderWidth = 2
      contentView.layer?.borderColor = NSColor.separatorColor.cgColor

      NSLayoutConstraint.activate([
        hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
        hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      ])
    }
  }

  let defaultChatPositionIsInverted: Bool

  override var canBecomeKey: Bool { true }

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

  override func close() {
    windowsViewModel.handle(.closeSidePanel)
  }

  override func hide() {
    lastWorkspaceFrame = nil
    lastWorkspaceElement = nil
    defer {
      changeMadeToWorkspaceFrame = nil
      super.hide()
    }

    // Ensures Xcode has focus.
    if
      let xcodeApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode").last,
      let trackedWindow = trackedWindow?.wrappedValue,
      isTrackedWindowOnScreen
    {
      WindowActivation.activateAppAndMakeWindowFront(xcodeApp, window: trackedWindow)
    }

    // Expand Xcode to re-take the space we might have used for the side panel when showing it.
    guard
      let changeMadeToWorkspaceFrame,
      changeMadeToWorkspaceFrame != 0,
      let trackedWindow,
      let workspaceFrame = trackedWindow.appKitFrame
    else { return }

    // Make sure we're not extending beyond the screen
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(workspaceFrame.origin) }) else {
      return
    }
    var newWorkspaceFrame =
      if changeMadeToWorkspaceFrame > 0 {
        // Expand to the left
        CGRect(
          origin: CGPoint(x: workspaceFrame.origin.x - changeMadeToWorkspaceFrame, y: workspaceFrame.origin.y),
          size: CGSize(width: workspaceFrame.width + changeMadeToWorkspaceFrame, height: workspaceFrame.height))
      } else {
        // Expand to the right
        CGRect(
          origin: workspaceFrame.origin,
          size: CGSize(width: workspaceFrame.width - changeMadeToWorkspaceFrame, height: workspaceFrame.height))
      }
    newWorkspaceFrame = screen.frame.intersection(newWorkspaceFrame)
    guard newWorkspaceFrame.width > 0, newWorkspaceFrame.height > 0 else {
      return
    }

    trackedWindow.set(appKitframe: newWorkspaceFrame)
  }

  private var lastWorkspaceFrame: CGRect?
  private var lastWorkspaceElement: AnyAXUIElement?
  private var lastWindowFrame: CGRect?

  /// Change made to the workspace frame to make room for the side panel when showing it.
  /// When positive, this represents the amount the workspace frame was shrunk from the left side.
  /// When negative, this represents the amount the workspace frame was shrunk from the right side.
  private var changeMadeToWorkspaceFrame: CGFloat?

  private let windowsViewModel: WindowsViewModel

  @MainActor
  private func frame(from window: AnyAXUIElement) -> CGRect? {
    // TODO: gracefully handle when the screen changes
    // TODO: make the experience moving the window nicer.
    // TODO: prevent the combine frame from extending beyond the screen.
    guard let workspaceFrame = window.appKitFrame else {
      // This can happen when there is no screen. For instance the laptop was closed.
      return nil
    }
    defer {
      lastWorkspaceFrame = workspaceFrame
      lastWorkspaceElement = window
    }
    if changeMadeToWorkspaceFrame == nil {
      // only do this once after the side panel is shown (this can happen several times if the side panel is hidden and shown again).

      // The desired frame is on the side of Xcode
      let desiredFrame = CGRect(
        origin: CGPoint(
          // Make sure the frame is within the screen bounds.
          x: defaultChatPositionIsInverted
            ? workspaceFrame.minX - defaultWidth
            : workspaceFrame.maxX,
          y: workspaceFrame.minY),
        size: CGSize(width: defaultWidth, height: workspaceFrame.height))

      // Make sure our frame will be within the screen bounds.
      let screen = NSScreen.screens.first(where: { $0.frame.contains(workspaceFrame.origin) })?.frame
      let (change, frameWithinScreen): (CGFloat, CGRect) = {
        guard let screen else {
          return (0, desiredFrame)
        }
        if screen.minX > desiredFrame.minX {
          return (
            screen.minX - desiredFrame.minX,
            CGRect(
              origin: CGPoint(x: screen.minX, y: desiredFrame.origin.y),
              size: CGSize(width: desiredFrame.width, height: desiredFrame.height)))
        }
        if screen.maxX < desiredFrame.maxX {
          return (
            screen.maxX - desiredFrame.maxX,
            CGRect(
              origin: CGPoint(x: screen.maxX - desiredFrame.width, y: desiredFrame.origin.y),
              size: CGSize(width: desiredFrame.width, height: desiredFrame.height)))
        }
        return (0, desiredFrame)
      }()

      changeMadeToWorkspaceFrame = change

      let xcodeFrame: CGRect =
        if change == 0 {
          workspaceFrame
        } else if change > 0 {
          // Shrink from the left
          CGRect(
            origin: CGPoint(x: workspaceFrame.origin.x + change, y: workspaceFrame.origin.y),
            size: CGSize(width: workspaceFrame.width - change, height: workspaceFrame.height))
        } else {
          // Shrink from the right
          CGRect(
            origin: CGPoint(x: workspaceFrame.origin.x, y: workspaceFrame.origin.y),
            size: CGSize(width: workspaceFrame.width + change, height: workspaceFrame.height))
        }
      window.set(appKitframe: xcodeFrame)

      return frameWithinScreen
    }
    return nil
  }

}
