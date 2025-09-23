// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AppLogo

public struct AppLogo: View {
  public var body: some View {
    SVGImage(resourceBundle.url(forResource: "cmd-logo", withExtension: "svg") ?? URL(filePath: ""))
  }

  public init() { }
}

extension Bundle {
  var icon: NSImage? {
    if let iconFile = infoDictionary?["CFBundleIconFile"] as? String {
      return NSImage(named: iconFile)
    }
    return nil
  }
}

public struct AppIcon: View {
  public var body: some View {
    if let image = Bundle.main.icon {
      Image(nsImage: image)
    } else {
      AppLogo()
    }
  }

  public init() { }
}

private let resourceBundle = Bundle.module
