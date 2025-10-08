// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG

#Preview("About Settings - Analytics Enabled") {
  AboutSettingsView(
    allowAnonymousAnalytics: .constant(true),
    automaticallyCheckForUpdates: .constant(true),
    fileEditMode: .constant(.xcodeExtension),
    launchHostAppWhenXcodeDidActivate: .constant(true))
    .frame(width: 600, height: 400)
    .padding()
}

#Preview("About Settings - Analytics Disabled") {
  AboutSettingsView(
    allowAnonymousAnalytics: .constant(false),
    automaticallyCheckForUpdates: .constant(false),
    fileEditMode: .constant(.directIO),
    launchHostAppWhenXcodeDidActivate: .constant(false))
    .frame(width: 600, height: 400)
    .padding()
}

#endif
