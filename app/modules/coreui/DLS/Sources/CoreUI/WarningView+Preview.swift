// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG

#Preview("WarningView") {
  WarningView(
    title: "Xcode Extension permissions required",
    subtext:
    "Xcode shortcuts need Xcode Extension permissions to work. Please grant permissions in Settings > Login Items & Extensions > Xcode Source Editor.")
    .frame(width: 400)
    .padding()
}

#Preview("WarningView - Dark Mode") {
  WarningView(
    title: "Xcode Extension permissions required",
    subtext:
    "Xcode shortcuts need Xcode Extension permissions to work. Please grant permissions in Settings > Login Items & Extensions > Xcode Source Editor.")
    .frame(width: 400)
    .padding()
    .preferredColorScheme(.dark)
}

#endif
