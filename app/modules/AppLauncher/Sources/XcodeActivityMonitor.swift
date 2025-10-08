// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import SharedUtilsFoundation

// MARK: - XcodeActivityMonitor

/// Monitors Xcode activity and launches the main app when Xcode becomes active
@MainActor
final class XcodeActivityMonitor: Sendable {
  init(
    userDefaults: UserDefaultsI)
  {
    self.userDefaults = userDefaults
    hostAppBundleIdentifier = Bundle.main.hostAppBundleId
  }

  private(set) var isXcodeActive = false

  func startMonitoring() {
    defaultLogger.log("Starting Xcode activity monitoring")

    // Check initial state
    checkXcodeActive()

    // Observe app activation notifications
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handleDidActivateApplication(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil)

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handleDidDeactivateApplication(_:)),
      name: NSWorkspace.didDeactivateApplicationNotification,
      object: nil)

    defaultLogger.log("Xcode activity monitoring started")
  }

  private let userDefaults: UserDefaultsI

  private let hostAppBundleIdentifier: String

  /// Whether to launch the host app when Xcode becomes active
  private var launchHostAppWhenXcodeDidActivate: Bool {
    let key = String.launchHostAppWhenXcodeDidActivate
    return userDefaults.object(forKey: key) == nil ? true : userDefaults.bool(forKey: key)
  }

  @objc
  private func handleDidActivateApplication(_ notification: NSNotification) {
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
      return
    }

    if app.isXcode {
      defaultLogger.log("Xcode became active")
      let wasActive = isXcodeActive
      isXcodeActive = true

      if !wasActive {
        defaultLogger.log("Xcode transitioned from inactive to active")

        // Launch the app if auto-launch is enabled
        if launchHostAppWhenXcodeDidActivate {
          do {
            try OpenHostApp.openHostApp { AppError($0) }
          } catch {
            defaultLogger.error("Failed to launch the host app", error)
          }
        } else {
          defaultLogger.log("Skipping launching the host app as the setting is disabled")
        }
      }
    }
  }

  @objc
  private func handleDidDeactivateApplication(_ notification: NSNotification) {
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
      return
    }

    if app.isXcode {
      defaultLogger.log("Xcode became inactive")
      isXcodeActive = false
    }
  }

  private func checkXcodeActive() {
    let frontmostApp = NSWorkspace.shared.frontmostApplication
    isXcodeActive = frontmostApp?.isXcode ?? false
    defaultLogger.log("Initial Xcode active state: \(isXcodeActive)")
  }
}

// MARK: - NSRunningApplication + Xcode

extension NSRunningApplication {
  var isXcode: Bool {
    bundleIdentifier == "com.apple.dt.Xcode"
  }
}
