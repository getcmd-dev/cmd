// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppKit
import Foundation
import XcodeObserverServiceInterface

extension MockXcodeObserver {
  convenience init(workspaceURL: URL, focussedTabURL: URL? = nil) {
    let mockElement = AnyAXUIElement(
      isOnScreen: { true },
      raise: { },
      appKitFrame: { .zero },
      cgFrame: { .zero },
      pid: { 0 },
      setAppKitframe: { _ in },
      id: "1")
    var tabs = [XcodeWorkspaceState.Tab]()
    if let focussedTabURL {
      tabs.append(.init(
        fileName: focussedTabURL.lastPathComponent,
        isFocused: true,
        knownPath: focussedTabURL,
        lastKnownContent: nil))
    }
    self.init(.state(
      XcodeState(
        activeApplicationProcessIdentifier: 1,
        previousApplicationProcessIdentifier: nil,
        xcodesState: [
          XcodeAppState(processIdentifier: 1, isActive: true, workspaces: [
            XcodeWorkspaceState(
              axElement: mockElement,
              url: workspaceURL,
              editors: [],
              isFocused: true,
              document: nil,
              tabs: tabs),
          ]),
        ])))
  }
}
