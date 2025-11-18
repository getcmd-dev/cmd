// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import ExtensionEventsInterface
import FileDiffFoundation
import FoundationInterfaces
import LoggingServiceInterface
import SettingsServiceInterface
import SharedValuesFoundation
import ShellServiceInterface
import ThreadSafe
import XcodeControllerServiceInterface
import XcodeObserverServiceInterface

// MARK: - DefaultXcodeController

@ThreadSafe
final class DefaultXcodeController: XcodeController, Sendable {

  convenience init(
    appEventHandlerRegistry: AppEventHandlerRegistry,
    shellService: ShellService,
    xcodeObserver: XcodeObserver,
    settingsService: SettingsService,
    fileManager: FileManagerI,
    appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState>)
  {
    self.init(
      appEventHandlerRegistry: appEventHandlerRegistry,
      shellService: shellService,
      xcodeObserver: xcodeObserver,
      settingsService: settingsService,
      fileManager: fileManager,
      appsActivationState: appsActivationState,
      timeout: ExtensionTimeout.applyFileChangeTimeout,
      canUseAppleScript: true,
      triggerExtensionCommand: { Task { @MainActor in
        try await Self.triggerExtensionCommand(
          commandName: ExtensionActionName.cmd.rawValue,
          xcodeObserver: xcodeObserver,
          shellService: shellService,
          settingsService: settingsService,
          appsActivationState: appsActivationState.currentValue)
      }})
  }

  init(
    appEventHandlerRegistry: AppEventHandlerRegistry,
    shellService: ShellService,
    xcodeObserver: XcodeObserver,
    settingsService: SettingsService,
    fileManager: FileManagerI,
    appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState>,
    timeout: TimeInterval,
    canUseAppleScript: Bool = false,
    triggerExtensionCommand: @escaping @Sendable () async throws -> Void)
  {
    self.appEventHandlerRegistry = appEventHandlerRegistry
    self.shellService = shellService
    self.xcodeObserver = xcodeObserver
    self.settingsService = settingsService
    self.fileManager = fileManager
    self.appsActivationState = appsActivationState
    self.triggerExtensionCommand = triggerExtensionCommand
    self.timeout = timeout
    self.canUseAppleScript = canUseAppleScript

    registerAppEventHandler()
  }

  let shellService: ShellService
  let xcodeObserver: XcodeObserver
  let fileManager: FileManagerI
  let appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState>

  #if DEBUG
  var currentExecutionId: String? {
    queuedRequests.first?.id.uuidString
  }
  #endif

  #if DEBUG
  @MainActor
  static func getXcode(xcodeObserver: XcodeObserver, shellService: ShellService) async -> NSRunningApplication? {
    // When in DEBUG mode, we first check if there is an instance of Xcode that has been launched by attaching to the extension.
    let xcodesState = xcodeObserver.state.wrapped?.xcodesState
    if xcodesState?.count ?? 0 > 1 {
      for pid in xcodesState?.map(\.processIdentifier) ?? [] {
        if await shellService.isXcodeInstanceUsedByDebugExtension(processIdentifier: pid) {
          if let app = NSRunningApplication(processIdentifier: pid) {
            return app
          }
        }
      }
    }
    if
      let processId = xcodesState?.first?.processIdentifier,
      let app = NSRunningApplication(processIdentifier: processId)
    {
      return app
    }
    defaultLogger.error("Could not find Xcode process id")
    return NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode").last
  }
  #else
  @MainActor
  static func getXcode(xcodeObserver: XcodeObserver, shellService _: ShellService) -> NSRunningApplication? {
    if
      let processId = xcodeObserver.state.wrapped?.xcodesState.first?.processIdentifier,
      let app = NSRunningApplication(processIdentifier: processId)
    {
      return app
    }
    defaultLogger.error("Could not find Xcode process id")
    return NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode").last
  }
  #endif

  /// Apply the file change using the Xcode extension.
  /// If other changes are pending, this will wait for them to complete first.
  func apply(fileChange: FileChange, editMode: FileEditMode? = nil) async throws {
    try await fileChangeTasksQueue.queueAndAwait { [weak self] in
      try await self?._apply(fileChange: fileChange, editMode: editMode)
    }
  }

  /// Open a file in Xcode at the specified line and column.
  func open(file: URL, line: Int?, column _: Int?) async throws {
    Task {
      do {
        try await Self.openFileWithAppleScript(at: file)
        if let line {
          try await shellService.runAndThrows("xed --line \(line) '\(file.path)'")
        }
      } catch {
        defaultLogger.error("Failed to open file", error)
      }
    }
  }

  func reloadExtension() async throws {
    _ = try await tasksQueue.queueAndAwait { [weak self] () -> ExtensionResult in
      guard let self else {
        throw AppError(message: "XcodeController deallocated")
      }
      let timeout: TimeInterval = 2.0

      return try await triggerExtension(input: .reloadSettings, timeout: timeout)
    }
  }

  // MARK: - Formatting Metadata Helpers

  func getFormattingMetadata() async throws -> FileFormattingMetadata {
    let result = try await tasksQueue.queueAndAwait { [weak self] () -> ExtensionResult in
      guard let self else {
        throw AppError(message: "XcodeController deallocated")
      }
      guard appsActivationState.currentValue.isXcodeActive == true else {
        // If Xcode is not active, we do not want to trigger the extension as this would have the side effect of activating Xcode.
        // Failing here has no user visible effect. It just means that the metadata will have to be fetched at a later time.
        throw AppError(message: "Xcode must be active to get formatting metadata")
      }

      let timeout: TimeInterval = 2.0

      return try await triggerExtension(input: .getFormattingMetadata, timeout: timeout)
    }

    switch result {
    case .formattingMetadataResult(let result):
      return try result.get()
    default:
      assertionFailure("Unexpected extension result type")
      throw AppError(message: "Unexpected extension result type")
    }
  }

  /// Unified request structure containing input, continuation, and ID
  private struct QueuedRequest {
    let id: UUID
    let input: ExtensionInput
    let continuation: @Sendable (Result<ExtensionResult, any Error>) -> Void
  }

  /// A serial queue to ensure we're applying a single file change at a time.
  private let fileChangeTasksQueue = TaskQueue<Void, any Error>()
  /// A serial queue to ensure we're processing a single extension request at a time.
  private let tasksQueue = TaskQueue<ExtensionResult, any Error>()

  /// Single unified queue for all extension requests
  private var queuedRequests = [QueuedRequest]()

  // Configuration variable that can be changed for testing.
  private let timeout: TimeInterval
  private let canUseAppleScript: Bool

  private let appEventHandlerRegistry: AppEventHandlerRegistry
  private let settingsService: SettingsService

  /// Trigger the Xcode extension (passed through DI and used for testing).
  private let triggerExtensionCommand: @Sendable () async throws -> Void

  @MainActor
  private static func triggerExtensionCommand(
    commandName: String,
    xcodeObserver: XcodeObserver,
    shellService: ShellService,
    settingsService: SettingsService,
    appsActivationState: AppsActivationState?)
    async throws
  {
    let needToActivateXcode = appsActivationState?.isXcodeActive != true
    let isAppActive = NSApplication.shared.isActive
    #if DEBUG
    guard let xcodeApp = await getXcode(xcodeObserver: xcodeObserver, shellService: shellService) else {
      defaultLogger.error("Could not find running Xcode")
      throw AXError.cannotComplete
    }
    #else
    guard let xcodeApp = getXcode(xcodeObserver: xcodeObserver, shellService: shellService) else {
      defaultLogger.error("Could not find running Xcode")
      throw AXError.cannotComplete
    }
    #endif

    if needToActivateXcode {
      if !xcodeApp.activate() {
        defaultLogger.error("Xcode not activated.")
        try? activateXcodeWithAppleScript()
      }
    }

    let appElement = AXUIElementCreateApplication(xcodeApp.processIdentifier)

    guard let menuBar = appElement.menuBar else {
      defaultLogger.error("Could not find menu bar")
      throw AXError.cannotComplete
    }

    #if DEBUG
    let appBundleId = settingsService.value(for: \.pointReleaseXcodeExtensionToDebugApp)
      ? Bundle.main.releaseHostAppBundleId
      : Bundle.main.hostAppBundleId
    #else
    let appBundleId = Bundle.main.hostAppBundleId
    #endif
    guard
      let menuItem = menuBar
        .firstChild(where: { el, _ in
          if el.title == commandName, el.identifier?.contains(appBundleId) == true {
            return .stopSearching
          }
          return .continueSearching
        })
    else {
      defaultLogger.error("Could not find '\(appBundleId):\(commandName)' menu")
      throw AXError.cannotComplete
    }

    if AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success {
      defaultLogger.log("Clicked the \(commandName) menu item")
    } else {
      defaultLogger.error("Failed to click \(commandName) menu item.")
      throw AXError.cannotComplete
    }
    if isAppActive, needToActivateXcode {
      NSApplication.shared.activate()
    }
  }

  private func registerAppEventHandler() {
    appEventHandlerRegistry.registerHandler { [weak self] event in
      guard let self else {
        return false
      }
      switch event {
      case let event as ExecuteExtensionRequestEvent:
        do {
          switch event.command {
          case ExtensionCommandName.getQueuedInput.rawValue:
            // Extension is asking for the first queued input
            guard let request = queuedRequests.first else {
              throw AppError(message: "No queued input available")
            }
            event.completion(.success(request.input))
            return true

          case ExtensionCommandName.sendResult.rawValue:
            // Extension is sending back the result
            let extensionRequest = try JSONDecoder().decode(RequestFromXcodeExtension<ExtensionResult>.self, from: event.data)
            handleExtensionResult(extensionRequest.input)
            event.completion(.success(EmptyResponse()))
            return true

          default:
            return false
          }
        } catch {
          defaultLogger.error("Failed to handle extension request: \(error)")
          event.completion(.failure(error))
          return true
        }

      default:
        return false
      }
    }
  }

  private func handleExtensionResult(_ result: ExtensionResult) {
    let continuation = inLock { state -> (@Sendable (Result<ExtensionResult, any Error>) -> Void)? in
      // Pop the first request from the queue
      guard !state.queuedRequests.isEmpty else {
        return nil
      }
      let request = state.queuedRequests.removeFirst()
      return request.continuation
    }

    guard let continuation else {
      defaultLogger.error("Received extension result but no pending request found. It might have timed out.")
      return
    }
    continuation(.success(result))
  }

  /// Apply the file change using the method specified in settings.
  private func _apply(fileChange: FileChange, editMode: FileEditMode?) async throws {
    guard fileManager.fileExists(atPath: fileChange.filePath.path) else {
      let data = fileChange.suggestedNewContent.utf8Data
      // TODO: look at making the required modification to the xcode project if necessary.
      try fileManager.write(data: data, to: fileChange.filePath)
      return
    }

    let fileEditMode = editMode ?? settingsService.value(for: \.fileEditMode)

    switch fileEditMode {
    case .xcodeExtension:
      // Try Xcode extension first, fall back to direct I/O if it fails
      do {
        try await applyWithXcodeExtension(fileChange: fileChange)
      } catch {
        let err = error
        defaultLogger.error("Failed to apply code change with Xcode extension, falling back to direct I/O: \(err)")
        if editMode != nil {
          // When a specific edit mode is set, we respect it.
          throw error
        } else {
          try await applyDirectIO(fileChange: fileChange)
        }
      }

    case .directIO:
      // Use direct I/O method
      try await applyDirectIO(fileChange: fileChange)
    }
  }

  /// Apply the file change using direct I/O to the file system.
  private func applyDirectIO(fileChange: FileChange) async throws {
    let data = fileChange.suggestedNewContent.utf8Data
    try fileManager.write(data: data, to: fileChange.filePath)
    defaultLogger.log("Successfully updated '\(fileChange.filePath.path)' using direct I/O.")
  }

  private func applyWithXcodeExtension(fileChange: FileChange) async throws {
    let result = try await tasksQueue.queueAndAwait { [weak self] () -> ExtensionResult in
      guard let self else {
        throw AppError(message: "XcodeController deallocated")
      }
      let start = Date()
      let timeout: TimeInterval = 2.0

      let openedFilePath = xcodeObserver.state.focusedWorkspace?.tabs.first(where: { $0.isFocused })?.knownPath?.path
      if openedFilePath != fileChange.filePath.path, canUseAppleScript {
        defaultLogger
          .log(
            "Opening file '\(fileChange.filePath)' in Xcode. Current file: \(openedFilePath ?? "nil")")
        try? await Self.openFileWithAppleScript(at: fileChange.filePath)
      }

      let result = try await triggerExtension(input: .applyEdit(fileChange), timeout: timeout)
      let duration = Date().timeIntervalSince(start)
      defaultLogger.log("Time to trigger extension: \(duration)")
      return result
    }
    switch result {
    case .applyEditResult(let result):
      try result.get()
    default:
      assertionFailure("Unexpected extension result type")
      throw AppError(message: "Unexpected extension result type")
    }
  }

  private func triggerExtension(input: ExtensionInput, timeout: TimeInterval) async throws -> ExtensionResult {
    // Queue the input that the extension will fetch when triggered.
    let requestId = UUID()
    let (future, continuation) = Future<ExtensionResult, Error>.make()

    let request = QueuedRequest(
      id: requestId,
      input: input,
      continuation: continuation)
    queuedRequests.append(request)

    // Trigger the cmd extension command which will process the reload
    Task {
      do {
        try await triggerExtensionCommand()
      } catch {
        // Clean up the queued request if the extension command fails
        let request = inLock { state -> DefaultXcodeController.QueuedRequest? in
          if let index = state.queuedRequests.firstIndex(where: { $0.id == requestId }) {
            return state.queuedRequests.remove(at: index)
          }
          return nil
        }
        defaultLogger.error("Failed to trigger extension", error)
        request?.continuation(.failure(error))
      }
    }

    Task { [weak self] in
      try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
      if
        let request = self?.inLock({ state -> DefaultXcodeController.QueuedRequest? in
          if let index = state.queuedRequests.firstIndex(where: { $0.id == requestId }) {
            return state.queuedRequests.remove(at: index)
          }
          return nil
        })
      {
        let error = AppError("The extension timeout")
        defaultLogger.error("Failed to trigger extension", error)
        request.continuation(.failure(error))
      }
    }
    return try await future.value
  }

}

extension BaseProviding where
  Self: XcodeObserverProviding,
  Self: AppEventHandlerRegistryProviding,
  Self: ShellServiceProviding,
  Self: SettingsServiceProviding,
  Self: FileManagerProviding,
  Self: AppsActivationStateProviding
{
  public var xcodeController: XcodeController {
    shared {
      DefaultXcodeController(
        appEventHandlerRegistry: appEventHandlerRegistry,
        shellService: shellService,
        xcodeObserver: xcodeObserver,
        settingsService: settingsService,
        fileManager: fileManager,
        appsActivationState: appsActivationState)
    }
  }
}

extension ShellService {
  /// Returns whether the instance  (assumed to be an Xcode instance) is the one launched by running the extension.
  func isXcodeInstanceUsedByDebugExtension(processIdentifier: pid_t) async -> Bool {
    do {
      return try await stdout("ps aux | grep \(processIdentifier)")?.contains("-NSDocumentRevisionsDebugMode YES") ?? false
    } catch {
      return false
    }
  }
}
