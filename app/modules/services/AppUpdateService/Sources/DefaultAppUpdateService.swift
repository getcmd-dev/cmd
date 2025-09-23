// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppUpdateServiceInterface
@preconcurrency import Combine
import DependencyFoundation
import FoundationInterfaces
import LoggingServiceInterface
import SettingsServiceInterface
@preconcurrency import Sparkle
import ThreadSafe

let updateLogger = defaultLogger.subLogger(subsystem: "appUpdate")

// MARK: - DefaultAppUpdateService

@ThreadSafe
final class DefaultAppUpdateService: AppUpdateService {
  init(
    settingsService: SettingsService,
    userDefaults: UserDefaultsI)
  {
    self.settingsService = settingsService
    self.userDefaults = userDefaults
    monitorSettingChanges()
  }

  var hasUpdateAvailable: ConcurrencyFoundation.ReadonlyCurrentValueSubject<AppUpdateResult, Never> {
    _hasUpdateAvailable.readonly()
  }

  func stopCheckingForUpdates() {
    canCheckForUpdates = false
  }

  func checkForUpdatesContinously() {
    #if DEBUG
    // Only check for updates in release.
    return
    #else
    canCheckForUpdates = true
    Task { @MainActor in
      startCheckingForUpdates()
    }
    #endif
  }

  func relaunch() {
    Task {
      /// When an update is available, checking again for an update will make Sparkle quit and relaunch.
      let updater = await UpdateChecker()
      _ = try? await updater.checkForUpdates()
    }
  }

  func isUpdateIgnored(_ update: AppUpdateInfo?) -> Bool {
    guard let update else { return false }
    return ignoredUpdateVersions.contains(update.version)
  }

  func ignore(update: AppUpdateInfo?) {
    guard let update else {
      updateLogger.error("No version provided to ignore update.")
      return
    }

    let ignoredVersions = ignoredUpdateVersions + [update.version]
    let newIgnoredVersions = (try? JSONEncoder().encode(ignoredVersions)).map { String(data: $0, encoding: .utf8) } ?? "[]"

    userDefaults.set(newIgnoredVersions ?? "[]", forKey: Self.ignoredVersionKey)
  }

  fileprivate static let ignoredVersionKey = "AppUpdateService.ignoredVersion"

  private let userDefaults: UserDefaultsI

  private var cancellables = Set<AnyCancellable>()
  private let settingsService: SettingsService

  private let delayBetweenChecks = Duration.seconds(60)

  private let _hasUpdateAvailable = CurrentValueSubject<AppUpdateResult, Never>(.noUpdateAvailable)
  private var canCheckForUpdates = false
  private var updateTask: Task<Void, Error>?

  private var ignoredUpdateVersions: [String] {
    let ignoredVersions = userDefaults.string(forKey: Self.ignoredVersionKey) ?? "[]"
    return (try? JSONDecoder().decode([String].self, from: Data(ignoredVersions.utf8))) ?? []
  }

  private func monitorSettingChanges() {
    settingsService.liveValue(for: \.automaticallyCheckForUpdates).sink { @Sendable [weak self] automaticallyCheckForUpdates in
      if automaticallyCheckForUpdates {
        Task { @MainActor in
          self?.checkForUpdatesContinously()
        }
      } else {
        Task { @MainActor in
          self?.stopCheckingForUpdates()
        }
      }
    }.store(in: &cancellables)
  }

  private func startCheckingForUpdates() {
    updateTask?.cancel()
    updateTask = Task { @MainActor [weak self] in
      while let self, canCheckForUpdates {
        guard hasUpdateAvailable.currentValue == .noUpdateAvailable else {
          // Stop checking for updates if an update is already available.
          // It appears that checking for update when one has been installed for the next launch will unexpectedly quit and relaunch the app.
          break
        }
        try Task.checkCancellation()
        let updater = UpdateChecker()
        try await Task { @MainActor in
          try await _hasUpdateAvailable.send(updater.checkForUpdates())
        }.value
        try await Task.sleep(for: delayBetweenChecks)
      }
    }
  }

}

// MARK: - UpdateChecker

/// A helper that checks for updates once.
@ThreadSafe
final class UpdateChecker: NSObject, Sendable {

  @MainActor
  override init() {
    super.init()

    setupUpdater()
  }

  @MainActor
  func checkForUpdates() async throws -> AppUpdateResult {
    if updater?.sessionInProgress == true {
      throw AppError("Update already in progress")
    }
    let (future, continuation) = Future<AppUpdateResult, Error>.make()
    let canContinue = inLock { state in
      guard state.continuation == nil else {
        return false
      }
      state.continuation = continuation
      return true
    }
    if !canContinue {
      continuation(.failure(AppError("Update already in progress")))
      return try await future.value
    }

    /// Remove the key used by Sparkle to avoid the update being delayed / cached.
    UserDefaults.standard.removeObject(forKey: "SULastCheckTime")

    try? updater?.start()
    updater?.resetUpdateCycle()
    updater?.checkForUpdates()

    return try await future.value
  }

  private var updateInfo: AppUpdateInfo?

  private var updater: SPUUpdater?
  private var continuation: (@Sendable (Result<AppUpdateResult, Error>) -> Void)?

  /// Ideally this would be part of the initializer, but Swift has issues with type checking some initializers when using macros.
  @MainActor
  private func setupUpdater() {
    let hostBundle = Bundle.main
    let applicationBundle = Bundle.main
    let userDriver = BackgroundUserDriver(
      onReceivedUpdateInfo: { [weak self] updateInfo in self?.updateInfo = updateInfo },
      onReadyToInstall: { [weak self] in
        self?.complete(with: Result<AppUpdateResult, Error>.success(.updateAvailable(info: self?.updateInfo)))
      })

    updater = SPUUpdater(
      hostBundle: hostBundle,
      applicationBundle: applicationBundle,
      userDriver: userDriver,
      delegate: self)
  }

  private func complete(with result: Result<AppUpdateResult, Error>) {
    let continuation = inLock { state in
      let continuation = state.continuation
      state.continuation = nil
      return continuation
    }
    continuation?(result)
  }

}

// MARK: SPUUpdaterDelegate

extension UpdateChecker: SPUUpdaterDelegate {
  func updaterShouldPromptForPermissionToCheck(forUpdates _: SPUUpdater) -> Bool {
    updateLogger.info("updaterShouldPromptForPermissionToCheck(forUpdates:)")
    return false
  }

  func updater(_: SPUUpdater, didDownloadUpdate _: SUAppcastItem) {
    updateLogger.info("updater(_:didDownloadUpdate:)")
  }

  func updater(_: SPUUpdater, didExtractUpdate _: SUAppcastItem) {
    updateLogger.info("updater(_:didExtractUpdate:)")
  }

  func updater(_: SPUUpdater, shouldProceedWithUpdate _: SUAppcastItem, updateCheck _: SPUUpdateCheck) throws {
    updateLogger.info("updater(_:shouldProceedWithUpdate:updateCheck:)")
  }

  func updater(
    _: SPUUpdater,
    willInstallUpdateOnQuit _: SUAppcastItem,
    immediateInstallationBlock _: @escaping () -> Void)
    -> Bool
  {
    updateLogger.info("updater(willInstallUpdateOnQuit:)")
    return true
  }

  func updater(_: SPUUpdater, mayPerform _: SPUUpdateCheck) throws {
    updateLogger.info("updater(_:mayPerform:)")
  }

  func updaterDidNotFindUpdate(_: SPUUpdater, error: any Error) {
    if (error as NSError).domain == SUSparkleErrorDomain, (error as NSError).code == SUError.noUpdateError.rawValue {
      defaultLogger.info("No update available")
    } else {
      defaultLogger.error("updaterDidNotFindUpdate(_:error:)", error)
    }
    complete(with: .success(.noUpdateAvailable))
  }

  func updaterWillRelaunchApplication(_: SPUUpdater) {
    updateLogger.info("updaterWillRelaunchApplication(_:)")
  }

  func bestValidUpdate(in appCast: SUAppcast, for _: SPUUpdater) -> SUAppcastItem? {
    updateLogger.info("bestValidUpdate(in:for:)")
    return appCast.items.first
  }

  func updaterMayCheck(forUpdates _: SPUUpdater) -> Bool {
    updateLogger.info("updaterMayCheck(forUpdates:)")
    return true
  }
}

// MARK: - BackgroundUserDriver

/// A Sparkle's user driver that is not shown to the user (works in the background)
final class BackgroundUserDriver: NSObject, SPUUserDriver, Sendable {

  init(
    onReceivedUpdateInfo: @escaping @Sendable (AppUpdateInfo) -> Void = { _ in },
    onReadyToInstall: @escaping @Sendable () -> Void = { })
  {
    self.onReceivedUpdateInfo = onReceivedUpdateInfo
    self.onReadyToInstall = onReadyToInstall
  }

  func show(_: SPUUpdatePermissionRequest) async -> SUUpdatePermissionResponse {
    updateLogger.info("Showing update permission request")
    return SUUpdatePermissionResponse(automaticUpdateChecks: true, automaticUpdateDownloading: true, sendSystemProfile: false)
  }

  func showUpdateReleaseNotes(with _: SPUDownloadData) {
    updateLogger.info("Showing update release notes")
  }

  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
    updateLogger.info("Failed to download release notes: \(error.localizedDescription)")
  }

  func showUpdateNotFoundWithError(_ error: any Error, acknowledgement _: @escaping () -> Void) {
    updateLogger.info("Update not found with error: \(error.localizedDescription)")
  }

  func showDownloadInitiated(cancellation _: @escaping () -> Void) {
    updateLogger.info("Download initiated")
  }

  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
    updateLogger.info("Download expected content length: \(expectedContentLength) bytes")
  }

  func showDownloadDidReceiveData(ofLength length: UInt64) {
    updateLogger.info("Download received data: \(length) bytes")
  }

  func showDownloadDidStartExtractingUpdate() {
    updateLogger.info("Started extracting update")
  }

  func showExtractionReceivedProgress(_ progress: Double) {
    updateLogger.info("Extraction progress: \(Int(progress * 100))%")
  }

  func showReadyToInstallAndRelaunch() async -> SPUUserUpdateChoice {
    updateLogger.info("Ready to install and relaunch - dismissing")
    onReadyToInstall()
    return SPUUserUpdateChoice.dismiss
  }

  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication _: @escaping () -> Void)
  {
    updateLogger.info("Installing update (app terminated: \(applicationTerminated))")
  }

  func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement _: @escaping () -> Void) {
    updateLogger.info("Update installed and relaunched: \(relaunched)")
  }

  func showUpdateInFocus() {
    updateLogger.info("Update in focus")
  }

  func showUserInitiatedUpdateCheck(cancellation _: @escaping () -> Void) {
    updateLogger.info("User initiated update check")
    // Do not call completion here as this would cancel the update.
  }

  func showUpdateFound(
    with updateItem: SUAppcastItem,
    state _: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void)
  {
    updateLogger.log("Update found: \(updateItem.displayVersionString) (\(updateItem.versionString))")
    let appUpdateInfo = AppUpdateInfo(
      version: updateItem.versionString,
      fileURL: updateItem.fileURL,
      releaseNotesURL: updateItem.fullReleaseNotesURL)
    onReceivedUpdateInfo(appUpdateInfo)
    reply(.install)
  }

  func showDownloadedUpdate(_ updateItem: SUAppcastItem, acknowledgement: @escaping () -> Void) {
    updateLogger.info("Update downloaded: \(updateItem.displayVersionString)")
    acknowledgement()
  }

  func showInstallingUpdate(withApplicationTerminated terminated: Bool) {
    updateLogger.info("Installing update (app terminated: \(terminated))")
  }

  func showUpdateInstallationDidFinish() {
    updateLogger.info("Update installation finished")
  }

  func showUpdateInstallationDidCancel() {
    updateLogger.info("Update installation cancelled")
  }

  func dismissUpdateInstallation() {
    updateLogger.info("Dismissing update installation")
  }

  func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
    updateLogger.info("Updater error: \(error.localizedDescription)")
    acknowledgement()
  }

  func showUpdateNotFoundAcknowledgement(completion: @escaping () -> Void) {
    updateLogger.info("No update found - app is up to date")
    completion()
  }

  private let onReceivedUpdateInfo: @Sendable (AppUpdateInfo) -> Void
  private let onReadyToInstall: @Sendable () -> Void

}

// MARK: - Dependency Injection

extension BaseProviding where
  Self: SettingsServiceProviding,
  Self: UserDefaultsProviding
{
  public var appUpdateService: AppUpdateService {
    shared {
      DefaultAppUpdateService(
        settingsService: settingsService,
        userDefaults: sharedUserDefaults)
    }
  }
}
