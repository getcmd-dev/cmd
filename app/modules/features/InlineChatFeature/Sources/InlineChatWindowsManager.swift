// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import XcodeObserverWindowsAdapter

@MainActor
public final class InlineChatWindowsManager: Sendable {
  public init() {
    windows.append(InlineChatWindow())

    for window in windows {
      window.show()
    }
  }

  private var windows = [XcodeWindow]()
}
