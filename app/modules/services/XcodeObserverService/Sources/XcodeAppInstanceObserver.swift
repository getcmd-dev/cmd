// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
@preconcurrency import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - XcodeAppInstanceObserver

@ThreadSafe
final class XcodeAppInstanceObserver: AXElementObserver, @unchecked Sendable {
  @MainActor
  init(runningApplication: NSRunningApplication, axNotificationPublisher: PassthroughSubject<AXNotification, Never>) {
    self.runningApplication = runningApplication
    self.axNotificationPublisher = axNotificationPublisher
    processIdentifier = runningApplication.processIdentifier
    let appElement = AXUIElementCreateApplication(runningApplication.processIdentifier)
    self.appElement = appElement

    let state = InternalXcodeAppState(
      processIdentifier: runningApplication.processIdentifier,
      workspaces: [],
      focusedWorkspaceURL: appElement.focusedWindow?.workspaceURL)
    internalState = .init(state)
    super.init(element: appElement)

    updateVisibleWorkspaceInfo()
    observeAXNotifications()
  }

  public var version: String? {
    if let version = _version {
      return version
    }
    let version = runningApplication.version
    _version = version
    return version
  }

  let appElement: AXUIElement

  var _version: String??

  let processIdentifier: Int32

  let runningApplication: NSRunningApplication

  var state: ReadonlyCurrentValueSubject<InternalXcodeAppState, Never> {
    .init(internalState.value, publisher: internalState.eraseToAnyPublisher())
  }

  /// Called when the inspector receives a notification from its own event source.
  var onDidReceiveAppActivationNotification: (@MainActor @Sendable (XcodeAppInstanceObserver, Bool) -> Void)? {
    set { _onDidReceiveAppActivationNotification = newValue }
    get { _onDidReceiveAppActivationNotification }
  }

  private typealias WorkspaceIdentifier = URL

  private let axNotificationPublisher: PassthroughSubject<AXNotification, Never>

  private var axSubscription: AnyCancellable?
  private var updateWorkspaceInfoTask: Task<Void, Error>?

  private let internalState: CurrentValueSubject<InternalXcodeAppState, Never>

  private var workspaceInspectors: [URL: XcodeWorkspaceObserver] = [:]

  private var workspaceSubscriptions: [URL: AnyCancellable] = [:]

  private var _onDidReceiveAppActivationNotification: (@MainActor @Sendable (XcodeAppInstanceObserver, Bool) -> Void)?

  @MainActor
  private func observeAXNotifications() {
    guard
      let axNotificationPublisher = try? AXNotificationPublisher(
        app: runningApplication,
        notificationNames:
        kAXTitleChangedNotification,
        kAXApplicationActivatedNotification,
        kAXApplicationDeactivatedNotification,
        kAXMovedNotification,
        kAXResizedNotification,
        kAXMainWindowChangedNotification,
        kAXFocusedWindowChangedNotification,
        kAXFocusedUIElementChangedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
        kAXCreatedNotification,
        kAXUIElementDestroyedNotification)
    else {
      logger.error("Failed to create AXNotificationPublisher")
      return
    }

    axSubscription = axNotificationPublisher.sink { [weak self] notification in
      guard let self else { return }

      guard let event = AXNotification(rawValue: notification.name) else {
        return
      }

      switch event {
      case .applicationActivated:
        updateVisibleWorkspaceInfo()
        updateWorkspaceInfoTask?.cancel()
        updateWorkspaceInfoTask = Task { [weak self] in
          guard let self else { return }
          // Also update workspace info after a delay, to ensure the workspace is fully loaded.
          try await Task.sleep(nanoseconds: 2_000_000_000)
          try Task.checkCancellation()
          updateVisibleWorkspaceInfo()
        }
        onDidReceiveAppActivationNotification?(self, true)

      case .applicationDeactivated:
        onDidReceiveAppActivationNotification?(self, false)

      case .focusedWindowChanged, .mainWindowChanged:
        updateFocusedWindow()

      case .focusedUIElementChanged:
        handleFocusedUIElementChanged()

      default: break
      }
      self.axNotificationPublisher.send(event)
    }
  }

  /// With Accessibility API, we can ONLY get the information of visible windows.
  @MainActor
  private func updateVisibleWorkspaceInfo() {
    let app = AXUIElementCreateApplication(processIdentifier)
    let windows = app.windows.filter { $0.identifier == "Xcode.WorkspaceWindow" }

    var visibleWorkspaces = [WorkspaceIdentifier: XcodeWorkspaceObserver]()
    let existingWorkspaces = workspaceInspectors

    for window in windows {
      guard let workspaceURL = window.workspaceURL else { continue }
      let workspace = existingWorkspaces[workspaceURL] ?? XcodeWorkspaceObserver(
        runningApplication: runningApplication,
        workspace: window,
        url: workspaceURL)
      visibleWorkspaces[workspaceURL] = workspace
    }

    let newWorkspaces = visibleWorkspaces.values.filter { !existingWorkspaces.keys.contains($0.workspaceURL) }
    let removedWorkspaces = existingWorkspaces.values.filter { !visibleWorkspaces.keys.contains($0.workspaceURL) }

    let worspacesState = internalState.value.workspaces.filter { existingWorkspaces.keys.contains($0.url) } + newWorkspaces
      .map(\.state.currentValue)
    updateStateWith(workspaces: worspacesState)

    for ws in removedWorkspaces { stopTracking(ws) }
    for ws in newWorkspaces { startTracking(ws) }

    if let focusedWorkspaceUrl = internalState.value.focusedWorkspaceURL {
      workspaceInspectors[focusedWorkspaceUrl]?.refresh()
    }
  }

  /// Returns the inspector for the corresponding workspace.
  /// If the window is not a workspace, it returns nil.
  /// If the inspector is already created, it returns the existing inspector.
  /// If the inspector is not created, it creates a new inspector and subscribes to it.
  @MainActor
  private func workspaceInspector(for window: AXUIElement) -> XcodeWorkspaceObserver? {
    guard let workspaceURL = window.workspaceURL else {
      // Likely the window is not a workspace.
      return nil
    }
    if let inspector = workspaceInspectors[workspaceURL] {
      return inspector
    }
    let inspector = XcodeWorkspaceObserver(runningApplication: runningApplication, workspace: window, url: workspaceURL)
    startTracking(inspector)
    return inspector
  }

  @MainActor
  private func updateFocusedWindow() {
    guard let window = appElement.focusedWindow else {
      updateStateWith(focusedWorkspaceURL: .some(nil))
      return
    }
    guard let workspace = workspaceInspector(for: window) else {
      // The window is not a workspace.
      return
    }
    updateStateWith(
      // move the focused workspace to first.
      workspaces: internalState.value.workspaces.sorted(by: { a, _ in a.url == workspace.workspaceURL }),
      focusedWorkspaceURL: workspace.workspaceURL)
  }

  @MainActor
  private func startTracking(_ workspaceInspector: XcodeWorkspaceObserver) {
    let cancellable = workspaceInspector.state.sink { [weak self] state in
      guard let self else { return }

      let workspacesState = self.state.currentValue.workspaces.map { workspace in
        workspace.url == state.url ? state : workspace
      }
      updateStateWith(workspaces: workspacesState)
    }

    let url = workspaceInspector.workspaceURL
    let (toCancel, toRelease) = inLock { state in
      let toCancel = state.workspaceSubscriptions.removeValue(forKey: url)
      let toRelease = state.workspaceInspectors.removeValue(forKey: url)
      state.workspaceInspectors[url] = workspaceInspector
      state.workspaceSubscriptions[url] = cancellable
      return (toCancel, toRelease)
    }
    // Ensures that any de-allocation / cancellation happens outside of the lock.
    toCancel?.cancel()
    _ = toRelease

    workspaceInspector.set(cleanupTask: cancellable)
    workspaceInspector.onElementInvalidated = { [weak self] inspector in
      guard let self, let inspector = inspector as? XcodeWorkspaceObserver else { return }
      stopTracking(inspector)
    }
  }

  @MainActor
  private func stopTracking(_ workspaceInspector: XcodeWorkspaceObserver) {
    let url = workspaceInspector.workspaceURL
    let (toCancel, toRelease) = inLock { state -> (AnyCancellable?, XcodeWorkspaceObserver?) in
      guard state.workspaceInspectors[url] === workspaceInspector else {
        // Already replaced
        return (nil, nil)
      }
      let toCancel = state.workspaceSubscriptions.removeValue(forKey: url)
      let toRelease = state.workspaceInspectors.removeValue(forKey: url)
      return (toCancel, toRelease)
    }
    toCancel?.cancel()
    _ = toRelease
  }

  @MainActor
  private func handleFocusedUIElementChanged() {
    updateVisibleWorkspaceInfo()
  }

  private func updateStateWith(
    workspaces: [InternalXcodeWorkspaceState]? = nil,
    focusedWorkspaceURL: URL?? = nil)
  {
    let currentState = internalState.value
    let newState = InternalXcodeAppState(
      processIdentifier: currentState.processIdentifier,
      workspaces: workspaces ?? currentState.workspaces,
      focusedWorkspaceURL: focusedWorkspaceURL ?? currentState.focusedWorkspaceURL)

    if newState != currentState {
      internalState.send(newState)
    }
  }

}
