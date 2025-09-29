// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import LoggingServiceInterface
import PermissionsServiceInterface
import ShellServiceInterface
import ThreadSafe

// MARK: - DefaultPermissionsService

@ThreadSafe
final class DefaultPermissionsService: PermissionsService {

  init(
    shellService: ShellService,
    userDefaults _: UserDefaults,
    bundle: Bundle,
    isAccessibilityPermissionGranted: @MainActor @escaping @Sendable () -> Bool,
    requestAccessibilityPermission: @MainActor @escaping @Sendable () -> Void,
    requestXcodeExtensionPermission: @MainActor @escaping @Sendable () -> Void,
    pollIntervalNS: UInt64 = 1_000_000_000)
  {
    self.shellService = shellService
    self.isAccessibilityPermissionGranted = isAccessibilityPermissionGranted
    self.requestAccessibilityPermission = requestAccessibilityPermission
    self.requestXcodeExtensionPermission = requestXcodeExtensionPermission
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
    }
  }

  func status(for permission: Permission) -> ReadonlyCurrentValueSubject<Bool?, Never> {
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
    }
  }

  private let shellService: ShellService
  private let bundle: Bundle

  private var isPollingAccessibilityPermissionStatus = false
  private var isPollingXcodeExtensionPermissionStatus = false

  private let pollIntervalNS: UInt64
  private let isAccessibilityPermissionGranted: @MainActor @Sendable () -> Bool
  private let requestAccessibilityPermission: @MainActor @Sendable () -> Void
  private let requestXcodeExtensionPermission: @MainActor @Sendable () -> Void
  private let accessibilityPermissionStatus = CurrentValueSubject<Bool?, Never>(nil)
  private let xcodeExtensionPermissionStatus = CurrentValueSubject<Bool?, Never>(nil)

  private func pollAccessibilityPermissionStatus() {
    Task { @MainActor in
      if isAccessibilityPermissionGranted() {
        accessibilityPermissionStatus.send(true)
      } else {
        accessibilityPermissionStatus.send(false)
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
        xcodeExtensionPermissionStatus.send(true)
      }
    } else {
      xcodeExtensionPermissionStatus.send(false)
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

}

extension BaseProviding where
  Self: ShellServiceProviding
{
  public var permissionsService: PermissionsService {
    shared {
      DefaultPermissionsService(
        shellService: shellService,
        userDefaults: .standard,
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
        })
    }
  }
}
