// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

extension Bundle {

  /// The name of the Xcode extension.
  public var xcodeExtensionName: String {
    // We use an invisible non unicode character in the extension name to allow for it to have the ~same name as the main app.
    (infoDictionary?["XCODE_EXTENSION_PRODUCT_NAME"] as? String)?.trimmingLeadingNonUnicodeCharacters ?? "cmd"
  }

  /// The bundle identifier for the host app. This is also the prefix of any identifier for other targets.
  public var hostAppBundleId: String {
    infoDictionary?["HOST_APP_BUNDLE_IDENTIFIER"] as? String ?? "dev.getcmd.command"
  }

  /// The bundle identifier for the Xcode extension. This is also the prefix of any identifier for other targets.
  public var xcodeExtensionBundleId: String {
    infoDictionary?["XCODE_EXTENSION_BUNDLE_IDENTIFIER"] as? String ?? "dev.getcmd.command.Extension"
  }

  /// The bundle identifier for the Xcode extension. This is also the prefix of any identifier for other targets.
  public var appLauncherBundleId: String {
    infoDictionary?["LAUNCH_AGENT_BUNDLE_IDENTIFIER"] as? String ?? "dev.getcmd.command.appLauncher"
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
    infoDictionary?["RELEASE_HOST_APP_BUNDLE_IDENTIFIER"] as? String ?? "dev.getcmd.command"
  }

  /// The app type, which maps to the Sparkle update channel (e.g., "stable" or "dev")
  public var appType: String {
    infoDictionary?["APP_DISTRIBUTION_CHANNEL"] as? String ?? "stable"
  }

  /// The path to the host app (used by AppLauncher to launch the main app)
  public var hostAppPath: String? {
    infoDictionary?["HOST_APP_PATH"] as? String
  }

  public var appLauncherVersion: String {
    infoDictionary?["AppLauncherVersion"] as? String ?? "unknown"
  }
}

extension String {
  fileprivate var trimmingLeadingNonUnicodeCharacters: String {
    String(drop(while: { $0.unicodeScalars.contains(where: { CharacterSet.alphanumerics.inverted.contains($0) }) }))
  }
}
