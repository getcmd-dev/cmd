// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppUpdateServiceInterface
import SwiftUI

#if DEBUG
private let appUpdateInfo = AppUpdateInfo(
  version: "1.0.0",
  fileURL: nil,
  releaseNotesURL: URL(string: "https://example.com/release-notes")!)
#Preview("AppUpdateWidget", traits: .sizeThatFitsLayout) {
  VisibleAppUpdateWidget(
    appUpdateInfo: appUpdateInfo,
    onRelaunchTapped: { },
    onIgnoreTapped: { })
}
#endif
