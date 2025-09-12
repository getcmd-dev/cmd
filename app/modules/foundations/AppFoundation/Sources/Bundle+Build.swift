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
    infoDictionary?["APP_BUNDLE_IDENTIFIER"] as? String ?? "dev.getcmd.command"
  }

  /// The bundle identifier for the RELEASE host app. This is also the prefix of any identifier for other targets in RELEASE.
  public var releaseHostAppBundleId: String {
    infoDictionary?["RELEASE_APP_BUNDLE_IDENTIFIER"] as? String ?? "dev.getcmd.command"
  }
}

extension String {
  fileprivate var trimmingLeadingNonUnicodeCharacters: String {
    String(drop(while: { $0.unicodeScalars.contains(where: { CharacterSet.alphanumerics.inverted.contains($0) }) }))
  }
}
