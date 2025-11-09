// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// Not handled

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
    appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState, Never>)
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
      startApplyingFileChangeWithXcodeExtension: { Task { @MainActor in
        try await Self.triggerExtension(
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
    appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState, Never>,
    timeout: TimeInterval,
    canUseAppleScript: Bool = false,
    startApplyingFileChangeWithXcodeExtension: @escaping @Sendable () async throws -> Void)
  {
    self.appEventHandlerRegistry = appEventHandlerRegistry
    self.shellService = shellService
    self.xcodeObserver = xcodeObserver
    self.settingsService = settingsService
    self.fileManager = fileManager
    self.appsActivationState = appsActivationState
    self.startApplyingFileChangeWithXcodeExtension = startApplyingFileChangeWithXcodeExtension
    self.timeout = timeout
    self.canUseAppleScript = canUseAppleScript

    registerAppEventHandler()
  }

  let shellService: ShellService
  let xcodeObserver: XcodeObserver
  let fileManager: FileManagerI
  let appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState, Never>

  #if DEBUG
  var currentExecutionId: String? {
    queuedRequests.first?.id.uuidString
  }
  #endif

  /// Apply the file change using the Xcode extension.
  /// If other changes are pending, this will wait for them to complete first.
  func apply(fileChange: FileChange, editMode: FileEditMode? = nil) async throws {
    try await tasksQueue.queueAndAwait { [weak self] in
      try await self?._apply(fileChange: fileChange, editMode: editMode)
    }
  }

  /// Open a file in Xcode at the specified line and column.
  func open(file: URL, line _: Int?, column _: Int?) async throws {
    Task {
      do {
        try await Self.openFileWithAppleScript(at: file)
      } catch {
        defaultLogger.error("Failed to open file with AppleScript", error)
      }
    }
  }

  func executeExtensionCommand(_ commandName: String) async throws {
    try await DefaultXcodeController.triggerExtensionCommand(
      commandName: commandName,
      xcodeObserver: xcodeObserver,
      shellService: shellService,
      settingsService: settingsService,
      appsActivationState: appsActivationState.currentValue)
  }

  func getFormattingMetadata() async throws -> FileFormattingMetadata {
    try await _getFormattingMetadata()
  }

  func reloadExtension() async throws {
    // Queue the reload settings input (no continuation needed since extension will crash)
    let requestId = UUID()
    inLock { state in
      let request = QueuedRequest(
        id: requestId,
        input: .reloadSettings,
        continuation: nil) // No continuation needed, extension will crash
      state.queuedRequests.append(request)
    }

    // Trigger the cmd extension command which will process the reload
    do {
      try await executeExtensionCommand(ExtensionCommandNames.cmd)
    } catch {
      // Clean up the queued request if the extension command fails
      inLock { state in
        if let index = state.queuedRequests.firstIndex(where: { $0.id == requestId }) {
          state.queuedRequests.remove(at: index)
        }
      }
      defaultLogger.error("Failed to reload extension", error)
      throw error
    }
  }

  /// Unified continuation type for all extension operations
  private enum PendingContinuation {
    case applyEdit(CheckedContinuation<Void, Error>)
    case formattingMetadata(CheckedContinuation<FileFormattingMetadata, Error>)
  }

  /// Unified request structure containing input, continuation, and ID
  private struct QueuedRequest {
    let id: UUID
    let input: ExtensionInput
    let continuation: PendingContinuation?
  }

  private let tasksQueue = TaskQueue<Void, any Error>()

  /// Single unified queue for all extension requests
  private var queuedRequests = [QueuedRequest]()

  // Configuration variable that can be changed for testing.
  private let timeout: TimeInterval
  private let canUseAppleScript: Bool

  private let appEventHandlerRegistry: AppEventHandlerRegistry
  private let settingsService: SettingsService

  /// Start applying the code change, typically by selecting the extension menu item in Xcode.
  private let startApplyingFileChangeWithXcodeExtension: @Sendable () async throws -> Void

  private func registerAppEventHandler() {
    appEventHandlerRegistry.registerHandler { [weak self] event in
      guard let self else {
        return false
      }
      switch event {
      case let event as ExecuteExtensionRequestEvent:
        do {
          let extensionRequest = try JSONDecoder().decode(ExtensionRequest.self, from: event.data)

          switch extensionRequest {
          case .getQueuedInput:
            // Extension is asking for the first queued input
            guard let request = queuedRequests.first else {
              throw AppError(message: "No queued input available")
            }
            event.completion(.success(request.input))
            return true

          case .sendResult(let result):
            // Extension is sending back the result
            handleExtensionResult(result)
            event.completion(.success(EmptyResponse()))
            return true
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
    let continuation = inLock { state -> PendingContinuation? in
      // Pop the first request from the queue
      guard !state.queuedRequests.isEmpty else {
        return nil
      }
      let request = state.queuedRequests.removeFirst()
      return request.continuation
    }

    // Handle reloadSettingsResult separately as it has no continuation
    if case .reloadSettingsResult = result {
      // Nothing to do, extension will crash and reload
      return
    }

    guard let continuation else {
      defaultLogger.error("Received extension result but no pending request found")
      return
    }

    // Resume the continuation based on result type
    switch (continuation, result) {
    case (.applyEdit(let cont), .applyEditResult(let applyResult)):
      switch applyResult {
      case .success:
        cont.resume()
      case .failure(let error):
        cont.resume(throwing: AppError(message: error.message))
      }

    case (.formattingMetadata(let cont), .formattingMetadataResult(let metadataResult)):
      switch metadataResult {
      case .success(let metadata):
        cont.resume(returning: metadata)
      case .failure(let error):
        cont.resume(throwing: AppError(message: error.message))
      }

    default:
      defaultLogger.error("Mismatched continuation and result types")
    }
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
    let start = Date()
    let timeout = timeout

    return try await withCheckedThrowingContinuation { continuation in
      let requestId = UUID()

      Task {
        inLock { state in
          let request = QueuedRequest(
            id: requestId,
            input: .applyEdit(fileChange),
            continuation: .applyEdit(continuation))
          state.queuedRequests.append(request)
        }

        do {
          if xcodeObserver.state.focusedWorkspace?.url != fileChange.filePath, canUseAppleScript {
            defaultLogger
              .log(
                "Opening file '\(fileChange.filePath)' in Xcode. Current file: \(xcodeObserver.state.focusedWorkspace?.url.path() ?? "nil")")
            try? await Self.openFileWithAppleScript(at: fileChange.filePath)
          }

          try await startApplyingFileChangeWithXcodeExtension()
          let duration = Date().timeIntervalSince(start)
          defaultLogger.log("Time to trigger extension: \(duration)")
        } catch {
          defaultLogger.error("triggerExtension failed: \(error)")
          let continuation = inLock { state -> CheckedContinuation<Void, Error>? in
            // Remove the request we just added
            if let index = state.queuedRequests.lastIndex(where: { $0.id == requestId }) {
              let request = state.queuedRequests.remove(at: index)
              if case .applyEdit(let cont) = request.continuation {
                return cont
              }
            }
            return nil
          }
          continuation?.resume(throwing: error)
        }
      }

      Task { [weak self] in
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        self?.handleTimeout(requestId: requestId)
      }
    }
  }

  // MARK: - Formatting Metadata Helpers

  private func _getFormattingMetadata() async throws -> FileFormattingMetadata {
    let timeout: TimeInterval = 2.0

    return try await withCheckedThrowingContinuation { continuation in
      let requestId = UUID()

      Task {
        inLock { state in
          let request = QueuedRequest(
            id: requestId,
            input: .getFormattingMetadata,
            continuation: .formattingMetadata(continuation))
          state.queuedRequests.append(request)
        }

        do {
          // Trigger the extension command to get metadata for the currently focused file
          try await DefaultXcodeController.triggerExtensionCommand(
            commandName: ExtensionCommandNames.cmd,
            xcodeObserver: xcodeObserver,
            shellService: shellService,
            settingsService: settingsService,
            appsActivationState: appsActivationState.currentValue)
        } catch {
          defaultLogger.error("Failed to trigger formatting metadata extension: \(error)")
          let continuation = inLock { state -> CheckedContinuation<FileFormattingMetadata, Error>? in
            // Remove the request we just added
            if let index = state.queuedRequests.lastIndex(where: { $0.id == requestId }) {
              let request = state.queuedRequests.remove(at: index)
              if case .formattingMetadata(let cont) = request.continuation {
                return cont
              }
            }
            return nil
          }
          continuation?.resume(throwing: error)
        }
      }

      Task { [weak self] in
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        self?.handleTimeout(requestId: requestId)
      }
    }
  }

  // MARK: - Timeout Handler

  /// Generic timeout handler that works for any request type
  private func handleTimeout(requestId: UUID) {
    let pendingContinuation = inLock { state -> PendingContinuation? in
      // Find and remove the request with the given ID
      guard let index = state.queuedRequests.firstIndex(where: { $0.id == requestId }) else {
        return nil
      }
      let request = state.queuedRequests.remove(at: index)
      return request.continuation
    }

    // Resume the continuation with a timeout error based on its type
    switch pendingContinuation {
    case .applyEdit(let continuation):
      continuation.resume(throwing: AppError(message: "Apply edit timed out"))
      defaultLogger.error("Extension timed-out while applying the edit.")

    case .formattingMetadata(let continuation):
      continuation.resume(throwing: AppError(message: "Get formatting metadata timed out"))
      defaultLogger.error("Extension timed-out while getting formatting metadata.")

    case .none:
      // Request was already completed or cancelled
      break
    }
  }

}

// MARK: - MenuSelector

extension DefaultXcodeController {

  @MainActor
  static func triggerExtension(
    xcodeObserver: XcodeObserver,
    shellService: ShellService,
    settingsService: SettingsService,
    appsActivationState: AppsActivationState?)
    async throws
  {
    try await triggerExtensionCommand(
      commandName: ExtensionCommandNames.cmd,
      xcodeObserver: xcodeObserver,
      shellService: shellService,
      settingsService: settingsService,
      appsActivationState: appsActivationState)
  }

  @MainActor
  static func triggerExtensionCommand(
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

  #if DEBUG
  @MainActor
  static func getXcode(xcodeObserver: XcodeObserver, shellService: ShellService) async -> NSRunningApplication? {
    // When in DEBUG mode, we first check if there is an instance of Xcode that has been launched by attaching to the extension.
    for pid in xcodeObserver.state.wrapped?.xcodesState.map(\.processIdentifier) ?? [] {
      if await shellService.isXcodeInstanceUsedByDebugExtension(processIdentifier: pid) {
        if let app = NSRunningApplication(processIdentifier: pid) {
          return app
        }
      }
    }
    if
      let processId = xcodeObserver.state.wrapped?.xcodesState.first?.processIdentifier,
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

}

// MARK: DefaultXcodeController + AppleScript
extension DefaultXcodeController {

  @MainActor
  static func run(appleScript: String) throws {
    guard let script = NSAppleScript(source: appleScript) else {
      assertionFailure("Could not create NSAppleScript object.")
      throw AppError(message: "Could not create NSAppleScript object.")
    }

    var errorDict: NSDictionary?
    script.executeAndReturnError(&errorDict)

    if let error = errorDict {
      defaultLogger.error("AppleScript Error: \(error)")
      throw AppError(message: "AppleScript Error: \(error)")
    }
  }

  @MainActor
  static func activateXcodeWithAppleScript() throws {
    try run(appleScript: """
        tell application "Xcode" to activate
        delay 0.1
      """)
  }

  /// Modify the content of the file using Apple Script. This might lead to a non ideal UX with the code moving around in the editor but is a good fallback.
  @MainActor
  private static func openFileWithAppleScript(at path: URL) throws {
    try run(appleScript: """
      tell application "Xcode"
          set theFilePath to "\(path.path)"
          open theFilePath
          repeat 10 times
              try
                  set doc to first source document whose path is theFilePath
                  exit repeat
              on error
                  delay 0.1
              end try
          end repeat
      end tell
      delay 0.1
      """)
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
