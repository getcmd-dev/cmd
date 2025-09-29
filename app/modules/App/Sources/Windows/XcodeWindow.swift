// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AccessibilityObjCFoundation
import AppKit
import Combine
import Dependencies
import Foundation
import XcodeObserverServiceInterface

/// A window that tracks and positions itself in relation to an Xcode workspace window.
/// This window can automatically manage its position and visibility based on the state of the tracked Xcode window
/// and the activation state of both applications.
class XcodeWindow: NSWindow {

  // MARK: - Initialization

  init(contentRect: NSRect) {
    @Dependency(\.xcodeObserver) var xcodeObserver
    axNotificationPublisher = xcodeObserver.axNotifications
    super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)

    initWindowProperties()
    initObservers()
    updatePositionContinuously()
  }

  /// The level that the window should have when it is active.
  var activatedLevel: NSWindow.Level {
    .floating
  }

  /// Whether the window will automatically position itself in relationship to Xcode.
  /// If false, the window's position will be managed by the user who can drag it.
  var isPositionAutomaticallyManaged = true {
    didSet {
      if isPositionAutomaticallyManaged {
        if shouldBeVisibleWhenAutomaticallyManaged {
          show()
          updatePosition(skippingIfUnchanged: false)
        } else {
          hide()
        }
      }
      updateLevel()
    }
  }

  /// The window (usually an Xcode workspace) that is tracked and that this window can be positioned in relationship to.
  private(set) var trackedWindow: AnyAXUIElement? {
    didSet {
      if trackedWindow != oldValue {
        trackedWindowNumber = nil
        isTrackedWindowMiniaturized = nil
        showWhenXcodeWindowDeminiaturized = false
        updatePosition(skippingIfUnchanged: true)
      }
    }
  }

  /// Whether the tracked window is on screen
  var isTrackedWindowOnScreen: Bool {
    guard let trackedWindow else { return false }
    if isTrackedWindowMiniaturized == true {
      // When the window is miniaturized, the window info's isOnScreen is not reliable, so we track this state separately.
      return false
    }
    if let trackedWindowNumber {
      return WindowInfo.window(withNumber: trackedWindowNumber)?.isOnScreen ?? false
    }
    let windowInfos = WindowInfo.findWindowsMatching(pid: trackedWindow.pid, cgFrame: trackedWindow.cgFrame)
      .filter(\.isOnScreen)

    if windowInfos.count == 1 {
      trackedWindowNumber = windowInfos.first?.windowNumber
    }

    return !windowInfos.isEmpty
  }

  // MARK: - Public API

  /// Update the window's level (floating / normal) to match whether Xcode is the frontmost application.
  func updateLevel() {
    if isActive {
      level = activatedLevel
    } else {
      level = .normal
    }
  }

  /// Subclasses should override this function. It is called when the window's position needs to be updated.
  /// - Returns: The frame that the window should be positioned at, or nil if the position cannot be determined.
  func getFrame() -> CGRect? {
    nil
  }

  /// Hides the window and deactivates it.
  func hide() {
    isShown = false
    deactivate()
    setIsVisible(false)
  }

  /// Shows the window and activates it.
  func show() {
    isShown = true
    setIsVisible(true)
    activate()
  }

  override func miniaturize(_ sender: Any?) {
    isShown = false
    super.miniaturize(sender)
  }

  override func deminiaturize(_ sender: Any?) {
    isShown = true
    super.deminiaturize(sender)
  }

  // MARK: - Constants

  private enum Constants {
    /// Time interval for position updates
    static let positionUpdateInterval: TimeInterval = 0.1
    /// Delay before reactivating window
    static let reactivationDelay: TimeInterval = 0.1
  }

  // MARK: - Dependencies

  @Dependency(\.xcodeObserver) private var xcodeObserver
  @Dependency(\.appsActivationState) private var appsActivationStatePublisher

  // MARK: - Private Properties

  private var axNotificationPublisher: AnyPublisher<AXNotification, Never>
  private var cancellables = Set<AnyCancellable>()
  private var _frame: CGRect?
  private var trackedWindowNumber: CGWindowID?
  private var positionTimer: Timer?

  /// Whether the window should behave like an active window (ie be frontmost etc)
  private var isActive = true

  /// Whether the window is visible.
  /// Note that we don't close the window, but instead hide it to work around memory bugs (see https://stackoverflow.com/a/13470694/2054629).
  private var isShown = true
  private var shouldBeVisibleWhenAutomaticallyManaged = true

  private var isTrackedWindowMiniaturized: Bool?
  private var showWhenXcodeWindowDeminiaturized = false

  /// Whether this window is on screen
  private var isOnScreen: Bool {
    (CGWindowListCopyWindowInfo(.optionAll, CGWindowID(windowNumber)) as? [WindowInfo])?
      .first(where: { ($0.windowNumber ?? CGWindowID(windowNumber + 1)) == windowNumber })?
      .isOnScreen ?? false
  }

  // MARK: - Private Methods

  /// Sets up initial window properties including level, visibility and release behavior
  private func initWindowProperties() {
    level = activatedLevel
    orderFrontRegardless()
    setIsVisible(true)
    isReleasedWhenClosed = false
  }

  /// Sets up observers for Xcode state, accessibility notifications, and app activation state
  private func initObservers() {
    xcodeObserver.statePublisher
      .sink { @Sendable [weak self] newState in
        Task { @MainActor in
          self?.trackedWindow = newState.focusedWorkspace?.axElement
        }
      }.store(in: &cancellables)

    axNotificationPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] notification in
        self?.handle(xcodeNotification: notification)
      }.store(in: &cancellables)

    appsActivationStatePublisher
      .receive(on: DispatchQueue.main)
      .sink { @Sendable [weak self] activationState in
        Task { @MainActor in
          self?.handle(activationState: activationState)
        }
      }.store(in: &cancellables)
  }

  /// Updates the window position if necessary based on tracked window visibility and position
  /// - Parameter skippingIfUnchanged: Whether to skip the update if the frame hasn't changed
  private func updatePosition(skippingIfUnchanged: Bool = true) {
    guard isPositionAutomaticallyManaged else { return }
    // Ensure that we are not visible if the tracked workspace is not visible.
    if !isTrackedWindowOnScreen {
      if isOnScreen {
        setIsVisible(false)
      }
      return
    }

    guard isActive else { return }
    guard let frame = getFrame() else { return }

    // Calling `getFrame` might have changed our activation state. Check again before updating the display.
    guard isActive else { return }

    guard frame != _frame || !skippingIfUnchanged || !isOnScreen else { return }
    _frame = frame

    setFrame(frame, display: true)
    setIsVisible(true)
    orderFrontRegardless()
  }

  /// Hides the window if position is automatically managed, otherwise marks it as not visible for when it will be.
  private func hideIfManaged() {
    if isPositionAutomaticallyManaged {
      hide()
    } else {
      shouldBeVisibleWhenAutomaticallyManaged = false
    }
  }

  /// Shows the window if position is automatically managed, otherwise marks it as visible for when it will be.
  private func showIfManaged() {
    if isPositionAutomaticallyManaged {
      show()
    } else {
      shouldBeVisibleWhenAutomaticallyManaged = true
    }
  }

  /// Deactivates the window and updates its level
  private func deactivate() {
    isActive = false
    updateLevel()
  }

  /// Activates the window if it's shown and updates its position
  private func activate() {
    guard isShown else { return }

    isActive = true
    orderFrontRegardless()
    updateLevel()
    updatePosition(skippingIfUnchanged: false)
  }

  /// Sets up a timer to continuously update the window position
  private func updatePositionContinuously() {
    positionTimer?.invalidate()
    let timer = Timer.scheduledTimer(withTimeInterval: Constants.positionUpdateInterval, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.updatePosition()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    positionTimer = timer
  }

  /// Handles the reception of an AX notification from Xcode
  /// - Parameter xcodeNotification: The accessibility notification received from Xcode
  private func handle(xcodeNotification: AXNotification) {
    switch xcodeNotification {
    case .windowMiniaturized:
      isTrackedWindowMiniaturized = true
      // .windowMiniaturized might be called several time for one action, so we preserve the existing value.
      showWhenXcodeWindowDeminiaturized = showWhenXcodeWindowDeminiaturized || isShown
      hideIfManaged()

    case .windowDeminiaturized:
      isTrackedWindowMiniaturized = false

      if isShown || showWhenXcodeWindowDeminiaturized {
        showIfManaged()
      }
      showWhenXcodeWindowDeminiaturized = false

    case .windowMoved:
      updatePosition(skippingIfUnchanged: false)

    case .applicationTerminated:
      hideIfManaged()

    default: break
    }
  }

  /// Handles changes in the activation state between Xcode and the host app
  /// - Parameter activationState: The new activation state
  private func handle(activationState: AppsActivationState) {
    switch activationState {
    case .bothActive, .xcodeActive:
      guard isShown else { return }
      activate()

    case .hostAppActive:
      guard isShown else { return }
      activate()

      // Raise the tracked window and then reactivate after a slight delay
      if let trackedWindow {
        trackedWindow.raise()
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + Constants.reactivationDelay) { [weak self] in
        self?.activate()
      }

    case .inactive:
      deactivate()
    }
  }

}
