// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG

#Preview("About Settings - Analytics Enabled") {
  AboutSettingsView(
    allowAnonymousAnalytics: .mutable(true),
    automaticallyCheckForUpdates: .mutable(true),
    fileEditMode: .mutable(.xcodeExtension),
    launchHostAppWhenXcodeDidActivate: .mutable(true),
    queueMessagesWhileStreaming: .mutable(true),
    enablePushNotifications: .mutable(true),
    accessibilityPermission: .constant(.grantedEnabled),
    xcodeExtensionPermission: .constant(.grantedEnabled),
    xcodeAutomationPermission: .constant(.grantedEnabled),
    pushNotificationsPermission: .constant(.grantedEnabled))
    .frame(width: 400, height: 600)
    .padding()
}

#Preview("About Settings - Analytics Disabled") {
  AboutSettingsView(
    allowAnonymousAnalytics: .mutable(false),
    automaticallyCheckForUpdates: .mutable(false),
    fileEditMode: .mutable(.directIO),
    launchHostAppWhenXcodeDidActivate: .mutable(false),
    queueMessagesWhileStreaming: .mutable(false),
    enablePushNotifications: .mutable(true),
    accessibilityPermission: .constant(.grantedEnabled),
    xcodeExtensionPermission: .constant(.grantedEnabled),
    xcodeAutomationPermission: .constant(.grantedEnabled),
    pushNotificationsPermission: .constant(.grantedEnabled))
    .frame(width: 400, height: 600)
    .padding()
}

#endif
