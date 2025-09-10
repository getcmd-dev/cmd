// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG

#Preview("Internal Settings - Component Only") {
  InternalSettingsView(
    repeatLastLLMInteraction: .constant(true),
    showOnboardingScreenAgain: .constant(true),
    pointReleaseXcodeExtensionToDebugApp: .constant(false),
    showInternalSettingsInRelease: .constant(false),
    defaultChatPositionIsInverted: .constant(false),
    enableAnalyticsAndCrashReporting: .constant(false))
    .frame(width: 600, height: 400)
    .padding()
}

#Preview("Internal Settings - Debug Enabled") {
  InternalSettingsView(
    repeatLastLLMInteraction: .constant(false),
    showOnboardingScreenAgain: .constant(true),
    pointReleaseXcodeExtensionToDebugApp: .constant(true),
    showInternalSettingsInRelease: .constant(true),
    defaultChatPositionIsInverted: .constant(true),
    enableAnalyticsAndCrashReporting: .constant(false))
    .frame(width: 600, height: 400)
    .padding()
}

#endif
