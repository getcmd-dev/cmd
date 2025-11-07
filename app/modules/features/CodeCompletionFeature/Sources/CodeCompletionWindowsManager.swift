// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import XcodeObserverWindowsAdapter

@MainActor
public final class CodeCompletionWindowsManager: Sendable {
  public init() {
    windows.append(CodeCompletionWindow())
//      windows.append(EditorFrameWindow())

    for window in windows {
      window.show()
      window.orderFrontRegardless()
    }
  }

  private var windows = [XcodeWindow]()
}
