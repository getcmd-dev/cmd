// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import os.log

let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.getcmd.command", category: "AppFoundation")

extension Bundle {

  /// The name of the Xcode extension.
  public var xcodeExtensionName: String {
    // We use an invisible non unicode character in the extension name to allow for it to have the ~same name as the main app.
    guard let name = (infoDictionary?["XCODE_EXTENSION_PRODUCT_NAME"] as? String)?.trimmingLeadingNonUnicodeCharacters else {
      logger.error("XCODE_EXTENSION_PRODUCT_NAME not found in Info.plist, using fallback 'cmd'")
      return "cmd"
    }
    return name
  }

  /// The bundle identifier for the host app. This is also the prefix of any identifier for other targets.
  public var hostAppBundleId: String {
    guard let bundleId = infoDictionary?["HOST_APP_BUNDLE_IDENTIFIER"] as? String else {
      logger.error("HOST_APP_BUNDLE_IDENTIFIER not found in Info.plist, using fallback 'dev.getcmd.command'")
      return "dev.getcmd.command"
    }
    return bundleId
  }

  /// The bundle identifier for the Xcode extension. This is also the prefix of any identifier for other targets.
  public var xcodeExtensionBundleId: String {
    guard let bundleId = infoDictionary?["XCODE_EXTENSION_BUNDLE_IDENTIFIER"] as? String else {
      logger.error("XCODE_EXTENSION_BUNDLE_IDENTIFIER not found in Info.plist, using fallback 'dev.getcmd.command.Extension'")
      return "dev.getcmd.command.Extension"
    }
    return bundleId
  }

  /// The bundle identifier for the Xcode extension. This is also the prefix of any identifier for other targets.
  public var appLauncherBundleId: String {
    guard let bundleId = infoDictionary?["LAUNCH_AGENT_BUNDLE_IDENTIFIER"] as? String else {
      logger.error("LAUNCH_AGENT_BUNDLE_IDENTIFIER not found in Info.plist, using fallback 'dev.getcmd.command.appLauncher'")
      return "dev.getcmd.command.appLauncher"
    }
    return bundleId
  }

  public var version: String {
    guard let version = infoDictionary?["CFBundleVersion"] as? String else {
      logger.error("CFBundleVersion not found in Info.plist, using fallback 'Unknown'")
      return "Unknown"
    }
    return version
  }

  public var shortVersion: String {
    guard let version = infoDictionary?["CFBundleShortVersionString"] as? String else {
      logger.error("CFBundleShortVersionString not found in Info.plist, using fallback 'Unknown'")
      return "Unknown"
    }
    return version
  }

  /// Whether the current process is the Xcode extension.
  public var isXcodeExtension: Bool {
    bundleIdentifier == xcodeExtensionBundleId
  }

  /// Whether the current process is the host application (the main application).
  public var isHostApp: Bool {
    bundleIdentifier == hostAppBundleId
  }

  /// The bundle identifier for the RELEASE host app. This is also the prefix of any identifier for other targets in RELEASE.
  public var releaseHostAppBundleId: String {
    guard let bundleId = infoDictionary?["RELEASE_HOST_APP_BUNDLE_IDENTIFIER"] as? String else {
      logger.error("RELEASE_HOST_APP_BUNDLE_IDENTIFIER not found in Info.plist, using fallback 'dev.getcmd.command'")
      return "dev.getcmd.command"
    }
    return bundleId
  }

  /// The app type, which maps to the Sparkle update channel (e.g., "stable" or "dev")
  public var appType: String {
    guard let appType = infoDictionary?["APP_DISTRIBUTION_CHANNEL"] as? String else {
      logger.error("APP_DISTRIBUTION_CHANNEL not found in Info.plist, using fallback 'stable'")
      return "stable"
    }
    return appType
  }

  /// The path to the host app (used by AppLauncher to launch the main app)
  public var hostAppPath: String? {
    infoDictionary?["HOST_APP_PATH"] as? String
  }

  public var appLauncherVersion: String {
    guard let version = infoDictionary?["AppLauncherVersion"] as? String else {
      logger.error("AppLauncherVersion not found in Info.plist, using fallback 'unknown'")
      return "unknown"
    }
    return version
  }
}

extension String {
  fileprivate var trimmingLeadingNonUnicodeCharacters: String {
    String(drop(while: { $0.unicodeScalars.contains(where: { CharacterSet.alphanumerics.inverted.contains($0) }) }))
  }
}
