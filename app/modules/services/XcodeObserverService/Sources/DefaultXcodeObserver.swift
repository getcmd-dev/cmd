// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import FoundationInterfaces
import LoggingServiceInterface
import PermissionsServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - DefaultXcodeObserver

@ThreadSafe
final class DefaultXcodeObserver: XcodeObserver {
  @MainActor
  init(
    permissionsService: PermissionsService,
    fileManager: FileManagerI,
    settingsService: SettingsService,
    shellService: ShellService)
  {
    self.permissionsService = permissionsService
    self.fileManager = fileManager
    self.settingsService = settingsService
    self.shellService = shellService
    fileLister = FileLister(
      fileManager: fileManager,
      shellService: shellService)

    let accessibilityPermissionStatus = permissionsService.status(for: .accessibility)
    update(with: accessibilityPermissionStatus.value)
    let accessibilitySubscription = accessibilityPermissionStatus.sink(receiveValue: update(with:))
    inLock { state in state.accessibilitySubscription = accessibilitySubscription }

    // Set global accessibility timeout to 250ms
    AXUIElement.setGlobalMessagingTimeout(0.25)
  }

  deinit {
    observationsCancellable?.cancel()
  }

  let fileManager: FileManagerI
  let shellService: ShellService

  var axNotifications: AnyPublisher<AXNotification, Never> {
    axNotificationPublisher.eraseToAnyPublisher()
  }

  var statePublisher: ReadonlyCurrentValueSubject<AXState<XcodeState>> {
    .init(internalState.value.normalized, publisher: internalState.map(\.normalized).eraseToAnyPublisher())
  }

  func listFiles(in workspace: URL, debounce: TimeInterval?) async throws -> ListFilesResult {
    try await fileLister.listFiles(in: workspace, debounce: debounce)
  }

  func filterIgnoredFiles(from files: [URL], in workspace: URL) async -> [URL] {
    await files.filterOutIgnoredFiles(root: workspace, shellService: shellService)
  }

  func getContent(of file: URL) throws -> String {
    let fileEditMode = settingsService.value(for: \.fileEditMode)
    switch fileEditMode {
    case .xcodeExtension:
      return try knownEditorContent(of: file) ?? fileManager.read(contentsOf: file, encoding: .utf8)
    case .directIO:
      return try fileManager.read(contentsOf: file, encoding: .utf8)
    }
  }

  private let fileLister: FileLister

  private var xcodeObservers = [Int32: XcodeAppInstanceObserver]()
  private let internalState = CurrentValueSubject<AXState<InternalXcodeState>, Never>(.unknown)
  private let axNotificationPublisher = PassthroughSubject<AXNotification, Never>()
  private let permissionsService: PermissionsService
  private let settingsService: SettingsService
  private var accessibilitySubscription: AnyCancellable? = nil

  private var xcodeObserverSubscriptions = [Int32: AnyCancellable]()

  private var observationsCancellable: AnyCancellable?

  private var activeApplicationProcessIdentifier: Int32? {
    internalState.value.wrapped?.activeApplicationProcessIdentifier
  }

  @MainActor
  private func update(with permissionStatus: PermissionStatus) {
    if permissionStatus == .unknown, internalState.value != .unknown {
      stopObservations()
      internalState.send(.unknown)
      return
    } else if !permissionStatus.isGranted, internalState.value != .missingAXPermission {
      stopObservations()
      internalState.send(.missingAXPermission)
      return
    } else if
      permissionStatus.isGranted, internalState.value == .missingAXPermission || internalState
        .value == .unknown
    {
      startObservations { state in
        internalState.send(.state(state))
      }
      return
    }
  }

  @objc @MainActor
  private func handle(didActivateApplicationNotification notification: NSNotification) {
    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
      handleActivation(of: app)
    }
  }

  @objc @MainActor
  private func handle(didDeactivateApplicationNotification notification: NSNotification) {
    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
      if app.processIdentifier == activeApplicationProcessIdentifier {
        handleActivation(of: nil)
      }
    }
  }

  @objc @MainActor
  private func handle(didTerminateApplicationNotification notification: NSNotification) {
    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
      handleTermination(of: app)
    }
  }

  @objc @MainActor
  private func handle(didLaunchApplicationNotification notification: NSNotification) {
    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
      handleLaunch(of: app)
    }
  }

  private func observeDidActivateApplicationNotification() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handle(didActivateApplicationNotification:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil)
  }

  private func observeDidDeactivateApplicationNotification() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handle(didDeactivateApplicationNotification:)),
      name: NSWorkspace.didDeactivateApplicationNotification,
      object: nil)
  }

  private func observeDidTerminateApplicationNotification() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handle(didTerminateApplicationNotification:)),
      name: NSWorkspace.didTerminateApplicationNotification,
      object: nil)
  }

  private func observeDidLaunchApplicationNotification() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handle(didLaunchApplicationNotification:)),
      name: NSWorkspace.didLaunchApplicationNotification,
      object: nil)
  }

  private func pollActiveInstance() -> AnyCancellable {
    Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        guard let self else { return }
        if let pid = NSWorkspace.shared.activeApplication()?["NSApplicationProcessIdentifier"] as? Int32 {
          handleActivation(of: pid)
        }
      }
  }

  private func pollDeadProcesses() -> AnyCancellable {
    Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.cleanupDeadProcesses()
      }
  }

  private func cleanupDeadProcesses() {
    let deadObservers = inLock { state in
      state.xcodeObservers.values.filter { observer in
        // Check if the process is still running
        observer.runningApplication.processIdentifier == -1 || observer.runningApplication.isTerminated
      }
    }

    for observer in deadObservers {
      stopTracking(xcodeApp: observer)
    }
  }

  /// Start observing instance states.
  /// - Parameter onStateCreated: called as soon as a new representation of the state is available.
  @MainActor
  private func startObservations(onStateCreated: (InternalXcodeState) -> Void) {
    let runningApplications = NSWorkspace.shared.runningApplications
    let xcodes = runningApplications
      .filter(\.isXcode)
      .map { XcodeAppInstanceObserver(
        runningApplication: $0,
        axNotificationPublisher: axNotificationPublisher,
        shellService: shellService) }

    let activeApplicationPid = NSWorkspace.shared.frontmostApplication?.processIdentifier

    let xcodesState = xcodes
      .map(\.state.value)

    let state = InternalXcodeState(
      activeApplicationProcessIdentifier: activeApplicationPid,
      previousApplicationProcessIdentifier: nil,
      xcodesState: xcodesState)
    onStateCreated(state)

    for newXcodeApp in xcodes {
      startTracking(newXcodeApp: newXcodeApp)
    }

    observeDidActivateApplicationNotification()
    observeDidDeactivateApplicationNotification()
    observeDidTerminateApplicationNotification()
    observeDidLaunchApplicationNotification()
    let activeInstanceCancellable = pollActiveInstance()
    let deadProcessesCancellable = pollDeadProcesses()

    let cancelObservations = AnyCancellable { [weak self] in
      guard let self else { return }
      NSWorkspace.shared.notificationCenter.removeObserver(self)
      activeInstanceCancellable.cancel()
      deadProcessesCancellable.cancel()
    }

    let toBeCancelled = inLock { state in
      let toBeCancelled = state.observationsCancellable
      state.observationsCancellable = cancelObservations
      return toBeCancelled
    }
    // ensures that the dereference happens outside the lock
    toBeCancelled?.cancel()
  }

  /// Remove all active observations.
  private func stopObservations() {
    let cancellables = inLock { state in
      let cancellables = Array(state.xcodeObserverSubscriptions.values) + [state.observationsCancellable]
      state.observationsCancellable = nil
      state.xcodeObserverSubscriptions.removeAll()
      return cancellables
    }
    // Ensure that we cancel outside of the lock.
    _ = cancellables
  }

  /// Modify the state when an instance is activated.
  @MainActor
  private func handleActivation(of app: NSRunningApplication) {
    if
      app.isXcode, xcodeObservers[app.processIdentifier] == nil
    {
      let newXcodeApp = XcodeAppInstanceObserver(
        runningApplication: app,
        axNotificationPublisher: axNotificationPublisher,
        shellService: shellService)
      startTracking(newXcodeApp: newXcodeApp)
    }
    handleActivation(of: app.processIdentifier)
  }

  /// Modify the state when an instance is activated.
  private func handleActivation(of appPid: Int32?) {
    guard let state = internalState.value.wrapped, state.activeApplicationProcessIdentifier != appPid else { return }

    updateStateWith(
      activeApplicationProcessIdentifier: appPid,
      // move the activated instance to first.
      xcodesState: state.xcodesState.sorted(by: { $1.processIdentifier == appPid }))
  }

  /// Modify the state when an instance is de-activated.
  ///
  /// This is done in `DefaultXcodeObserver` instead of `XcodeAppInstanceObserver` to ensure that
  /// the activation state of _all_ instances is updated at once, and that we don't broadcast an inconsistent state
  /// where several (or no) instance are activated.
  private func handleTermination(of app: NSRunningApplication) {
    // When an app terminates, its processIdentifier may become -1.
    // We need to find the observer by checking all observers for a matching running application.
    let observerToStop = inLock { state in
      state.xcodeObservers.values.first { $0.runningApplication == app }
    }
    observerToStop.map(stopTracking(xcodeApp:))
  }

  /// Modify the state when a new application is launched.
  @MainActor
  private func handleLaunch(of app: NSRunningApplication) {
    if app.isXcode, xcodeObservers[app.processIdentifier] == nil {
      let newXcodeApp = XcodeAppInstanceObserver(
        runningApplication: app,
        axNotificationPublisher: axNotificationPublisher,
        shellService: shellService)
      startTracking(newXcodeApp: newXcodeApp)
    }
  }

  /// Start tracking a new instance of Xcode, and update the state.
  @MainActor
  private func startTracking(newXcodeApp: XcodeAppInstanceObserver) {
    guard case .state(let state) = internalState.value else {
      assertionFailure("tracking Xcode without having AX permissions")
      return
    }
    updateStateWith(
      xcodesState: [
        newXcodeApp.state.value,
      ] + state.xcodesState
        .filter { $0.processIdentifier != newXcodeApp.processIdentifier })

    let cancellable = Atomic<AnyCancellable?>(nil)

    let (toCancel, toDeinit): (AnyCancellable?, XcodeAppInstanceObserver?) = inLock { state in
      let toCancel = state.xcodeObserverSubscriptions[newXcodeApp.processIdentifier]
      state.xcodeObserverSubscriptions[newXcodeApp.processIdentifier] = AnyCancellable { cancellable.value?.cancel() }
      let toDeinit = state.xcodeObservers[newXcodeApp.processIdentifier]
      state.xcodeObservers[newXcodeApp.processIdentifier] = newXcodeApp
      return (toCancel, toDeinit)
    }
    // ensure that the cancellation is done outside of the lock.
    _ = toCancel
    _ = toDeinit

    // subscribe after updating the internal state.
    cancellable.set(to: newXcodeApp.state.sink { [weak self] newValue in
      guard let self, let state = internalState.value.wrapped else { return }
      updateStateWith(
        xcodesState: state.xcodesState.map { oldValue in
          oldValue.processIdentifier == newValue.processIdentifier ? newValue : oldValue
        })
    })

    // Subscribe to app state notification the inspector will receive, to ensure they are consistent with the one received from NSWorkspace.
    newXcodeApp.onDidReceiveAppActivationNotification = { [weak self] inspector, isActive in
      guard let self else { return }
      if isActive {
        handleActivation(of: inspector.runningApplication)
      } else {
        if internalState.value.wrapped?.activeApplicationProcessIdentifier == inspector.processIdentifier {
          handleActivation(of: nil)
        }
      }
    }
  }

  /// Stop tracking a new instance of Xcode, and update the state.
  private func stopTracking(xcodeApp: XcodeAppInstanceObserver) {
    guard let state = internalState.value.wrapped else {
      assertionFailure("tracking Xcode without having AX permissions")
      return
    }
    let xcodeState = xcodeApp.state.value

    let toRelease: (AnyCancellable?, XcodeAppInstanceObserver?) = inLock { state in
      let toCancel = state.xcodeObserverSubscriptions[xcodeState.processIdentifier]
      state.xcodeObserverSubscriptions.removeValue(forKey: xcodeState.processIdentifier)

      let removedInspector = state.xcodeObservers[xcodeApp.processIdentifier]
      return (toCancel, removedInspector)
    }
    // ensure that the cancellation / deinit is done outside of the lock.
    _ = toRelease
    updateStateWith(xcodesState: state.xcodesState.filter { $0.processIdentifier != xcodeState.processIdentifier })
  }

  private func updateStateWith(
    activeApplicationProcessIdentifier: Int32? = nil,
    xcodesState: [InternalXcodeAppState]? = nil)
  {
    guard case .state(let state) = internalState.value else { return }
    let previousApplicationProcessIdentifier: Int32?? =
      if let activeApplicationProcessIdentifier {
        activeApplicationProcessIdentifier
      } else {
        nil
      }

    let newState = InternalXcodeState(
      activeApplicationProcessIdentifier: activeApplicationProcessIdentifier ?? state.activeApplicationProcessIdentifier,
      previousApplicationProcessIdentifier: previousApplicationProcessIdentifier ?? state.previousApplicationProcessIdentifier,
      xcodesState: xcodesState ?? state.xcodesState)

    if newState != state {
      internalState.send(.state(newState))
    }
  }

}

extension BaseProviding where
  Self: PermissionsServiceProviding,
  Self: FileManagerProviding,
  Self: SettingsServiceProviding,
  Self: ShellServiceProviding
{
  public var xcodeObserver: XcodeObserver {
    shared {
      MainActor.assumeIsolated { DefaultXcodeObserver(
        permissionsService: permissionsService,
        fileManager: fileManager,
        settingsService: settingsService,
        shellService: shellService) }
    }
  }
}

extension NSRunningApplication {
  public var isXcode: Bool { bundleIdentifier == "com.apple.dt.Xcode" }
}

let logger = defaultLogger.subLogger(subsystem: "XcodeObservation")
