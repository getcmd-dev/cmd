// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import PermissionsServiceInterface
import ShellServiceInterface
import ThreadSafe
import UserNotifications

// MARK: - DefaultPermissionsService

@ThreadSafe
final class DefaultPermissionsService: PermissionsService {

  init(
    shellService: ShellService,
    userDefaults: UserDefaultsI,
    bundle: Bundle,
    isAccessibilityPermissionGranted: @MainActor @escaping @Sendable () -> Bool,
    requestAccessibilityPermission: @MainActor @escaping @Sendable () -> Void,
    requestXcodeExtensionPermission: @MainActor @escaping @Sendable () -> Void,
    isPushNotificationPermissionGranted: @MainActor @escaping @Sendable () async -> Bool,
    requestPushNotificationPermission: @MainActor @escaping @Sendable () async -> Void,
    pollIntervalNS: UInt64 = 1_000_000_000)
  {
    self.shellService = shellService
    self.userDefaults = userDefaults
    self.isAccessibilityPermissionGranted = isAccessibilityPermissionGranted
    self.requestAccessibilityPermission = requestAccessibilityPermission
    self.requestXcodeExtensionPermission = requestXcodeExtensionPermission
    self.isPushNotificationPermissionGranted = isPushNotificationPermissionGranted
    self.requestPushNotificationPermission = requestPushNotificationPermission
    self.pollIntervalNS = pollIntervalNS
    self.bundle = bundle
  }

  func request(permission: Permission) {
    switch permission {
    case .accessibility:
      Task { @MainActor in
        requestAccessibilityPermission()
      }

    case .xcodeExtension:
      Task { @MainActor in
        requestXcodeExtensionPermission()
      }

    case .pushNotification:
      Task { @MainActor in
        await requestPushNotificationPermission()
      }
    }
  }

  func status(for permission: Permission) -> ReadonlyCurrentValueSubject<PermissionStatus> {
    switch permission {
    case .accessibility:
      let isPolling: Bool = inLock { state in
        let isPolling = state.isPollingAccessibilityPermissionStatus
        state.isPollingAccessibilityPermissionStatus = true
        return isPolling
      }
      if !isPolling {
        pollAccessibilityPermissionStatus()
      }
      return accessibilityPermissionStatus
        .readonly(removingDuplicate: true)

    case .xcodeExtension:
      let isPolling: Bool = inLock { state in
        let isPolling = state.isPollingXcodeExtensionPermissionStatus
        state.isPollingXcodeExtensionPermissionStatus = true
        return isPolling
      }
      if !isPolling {
        Task { await pollXcodeExtensionPermissionStatus() }
      }
      return xcodeExtensionPermissionStatus
        .readonly(removingDuplicate: true)

    case .pushNotification:
      let isPolling: Bool = inLock { state in
        let isPolling = state.isPollingPushNotificationPermissionStatus
        state.isPollingPushNotificationPermissionStatus = true
        return isPolling
      }
      if !isPolling {
        Task { await pollPushNotificationPermissionStatus() }
      }
      return pushNotificationPermissionStatus
        .readonly(removingDuplicate: true)
    }
  }

  func enablePushNotifications() {
    userDefaults.set(false, forKey: .arePushNotificationsDisabled)
    if pushNotificationPermissionStatus.value.isGranted {
      pushNotificationPermissionStatus.send(.grantedEnabled)
    }
  }

  func disablePushNotifications() {
    userDefaults.set(true, forKey: .arePushNotificationsDisabled)
    if pushNotificationPermissionStatus.value.isGranted {
      pushNotificationPermissionStatus.send(.grantedDisabled)
    }
  }

  private let shellService: ShellService
  private let userDefaults: UserDefaultsI
  private let bundle: Bundle

  private var isPollingAccessibilityPermissionStatus = false
  private var isPollingXcodeExtensionPermissionStatus = false
  private var isPollingPushNotificationPermissionStatus = false

  private let pollIntervalNS: UInt64
  private let isAccessibilityPermissionGranted: @MainActor @Sendable () -> Bool
  private let requestAccessibilityPermission: @MainActor @Sendable () -> Void
  private let requestXcodeExtensionPermission: @MainActor @Sendable () -> Void
  private let isPushNotificationPermissionGranted: @MainActor @Sendable () async -> Bool
  private let requestPushNotificationPermission: @MainActor @Sendable () async -> Void
  private let accessibilityPermissionStatus = CurrentValueSubject<PermissionStatus, Never>(.unknown)
  private let xcodeExtensionPermissionStatus = CurrentValueSubject<PermissionStatus, Never>(.unknown)
  private let pushNotificationPermissionStatus = CurrentValueSubject<PermissionStatus, Never>(.unknown)

  private func pollAccessibilityPermissionStatus() {
    Task { @MainActor in
      if isAccessibilityPermissionGranted() {
        accessibilityPermissionStatus.send(.grantedEnabled)
      } else {
        accessibilityPermissionStatus.send(.notGranted)
        let pollIntervalNS = pollIntervalNS
        Task { [weak self] in
          try await Task.sleep(nanoseconds: pollIntervalNS)
          self?.pollAccessibilityPermissionStatus()
        }
      }
    }
  }

  private func pollXcodeExtensionPermissionStatus() async {
    if await isXcodeExtensionPermissionGranted() {
      Task { @MainActor in
        xcodeExtensionPermissionStatus.send(.grantedEnabled)
      }
    } else {
      xcodeExtensionPermissionStatus.send(.notGranted)
      let pollIntervalNS = pollIntervalNS
      Task { [weak self] in
        try await Task.sleep(nanoseconds: pollIntervalNS)
        await self?.pollXcodeExtensionPermissionStatus()
      }
    }
  }

  private func isXcodeExtensionPermissionGranted() async -> Bool {
    guard let output = try? await shellService.stdout("ps aux | grep '\(bundle.xcodeExtensionName)'") else {
      defaultLogger.error("`ps aux | grep '\(bundle.xcodeExtensionName)'` failed to return an output")
      return false
    }
    #if DEBUG
    let isGranted = output.contains("cmd (Debug).appex")
    #else
    let isGranted = output.contains("cmd.appex")
    #endif
    return isGranted
  }

  private func pollPushNotificationPermissionStatus() async {
    if await isPushNotificationPermissionGranted() {
      Task { @MainActor in
        let arePushNotificationsDisabled = userDefaults.bool(forKey: .arePushNotificationsDisabled)
        pushNotificationPermissionStatus.send(arePushNotificationsDisabled ? .grantedDisabled : .grantedEnabled)
      }
    } else {
      pushNotificationPermissionStatus.send(.notGranted)
      let pollIntervalNS = pollIntervalNS
      Task { [weak self] in
        try await Task.sleep(nanoseconds: pollIntervalNS)
        await self?.pollPushNotificationPermissionStatus()
      }
    }
  }

}

extension BaseProviding where
  Self: ShellServiceProviding,
  Self: UserDefaultsProviding
{
  public var permissionsService: PermissionsService {
    shared {
      DefaultPermissionsService(
        shellService: shellService,
        userDefaults: sharedUserDefaults,
        bundle: .main,
        isAccessibilityPermissionGranted: { AXIsProcessTrusted() },
        requestAccessibilityPermission: {
          AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
          ] as NSDictionary)
          if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
          }
        },
        requestXcodeExtensionPermission: {
          if
            let url =
            URL(
              string: "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.dt.Xcode.extension.source-editor")
          {
            NSWorkspace.shared.open(url)
          }
        },
        isPushNotificationPermissionGranted: {
          let center = UNUserNotificationCenter.current()
          let settings = await center.notificationSettings()
          return settings.authorizationStatus == .authorized
        },
        requestPushNotificationPermission: {
          let center = UNUserNotificationCenter.current()
          do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
          } catch {
            defaultLogger.error("Failed to request push notification permission: \(error)")
          }
        })
    }
  }
}

extension String {
  static let arePushNotificationsDisabled = "arePushNotificationsDisabled"
}
