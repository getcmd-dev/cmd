// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AccessibilityObjCFoundation
import AppKit
import Dependencies
import DLS
import FoundationInterfaces
import LoggingServiceInterface
import RoutingFoundation
import SettingsServiceInterface
import SwiftUI
import XcodeObserverServiceInterface
import XcodeObserverWindowsAdapter

// MARK: - BorderView

struct BorderView: View {
  var body: some View {
    VStack {
      Spacer()
      HStack {
        Spacer()
      }
    }
    .border(.red)
  }
}

// MARK: - EditorFrameWindow

/// A side panel displayed on the side of Xcode.
final class EditorFrameWindow: XcodeWindow {

  init() {
    let content = AnyView(BorderView())

    super.init(contentRect: .zero)

    styleMask = [.borderless]
    hasShadow = false
    isOpaque = false

    collectionBehavior = [
      .fullScreenAuxiliary,
      .fullScreenPrimary,
      .fullScreenAllowsTiling,
    ]

    setFrame(.zero, display: isVisible)
    makeKeyAndOrderFront(nil)

    backgroundColor = .clear

    let root = BorderView()

    let hostingView = NSHostingView(rootView: root)
    self.hostingView = hostingView

    hostingView.translatesAutoresizingMaskIntoConstraints = false
    contentView = hostingView
  }

  override func getFrame() -> CGRect? {
    guard
      let editor = xcodeObserver.state.focusedWorkspace?.editors.first(where: { $0.isFocused }),
      let editorFrame = editor.axElement.appKitFrame,
      let scrollViewFrame = editor.axElement.wrappedValue?.parent?.appKitFrame
    else {
      return nil
    }
    let frame = editorFrame.intersection(scrollViewFrame)
    print(frame)
    print(editor.axElement.debugDescription)
    return frame
  }

//  override func getUpdatedContentFrame() -> (minX: CGFloat?, maxX: CGFloat?, minY: CGFloat?, maxY: CGFloat?)? {
//      guard let editor = xcodeObserver.state.focusedWorkspace?.editors.first(where: { $0.isFocused }),
//      let frame = editor.axElement.appKitFrame else {
//          return nil
//      }
//      print(xcodeObserver.state.focusedWorkspace?.editors.first(where: { $0.isFocused })?.axElement.debugDescription)
//      return (minX: frame.minX,
//              maxX: frame.maxX,
//              minY: frame.minY,
//              maxY: frame.maxY)
//  }

  private var hostingView: NSView?

}
