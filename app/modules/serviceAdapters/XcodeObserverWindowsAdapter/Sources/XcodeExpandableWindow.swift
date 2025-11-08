// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Dependencies
import SwiftUI
import XcodeObserverServiceInterface

// MARK: - ExpandableXcodeWindow

/// A Window whose content can expand in size as needed (as long as it's within Xcode's window bounds) in any set direction.
open class ExpandableXcodeWindow<Content: View>: XcodeWindow {

  public init(content: Content) {
    @Dependency(\.xcodeObserver) var xcodeObserver
    let frame = Self.frame(xcodeObserver: xcodeObserver)
    super.init(
      contentRect: frame ?? .zero)

    contentView = NSHostingView(
      rootView: ExpandableViewContainer(
        containerInfo: containerInfo,
        content: content))
  }

  /// To be overriden.
  /// Return the frame for the content, in the AppKit coordinate (y=0 is the bottom of the screen).
  /// Each value that is `nil` will be treated as a direction the content can expand to, as much as the parent view allows.
  /// Each value that is not `nil` will be matched exactly.
  ///
  /// For example (minX: 100, maxX: 200, minY: 300, maxY: nil) will allow the content to expand in height, while maintaining its bottom at 300 in AppKit coordinates.
  /// On the horizontal axis, the content will be exactly between 100 and 200.
  open func getUpdatedContentFrame() -> (minX: CGFloat?, maxX: CGFloat?, minY: CGFloat?, maxY: CGFloat?)? {
    fatalError("Not implemented")
  }

  public override func getFrame() -> CGRect? {
    // Those frames are in AppKit coordinate, where y=0 is the bottom.
    let containerFrame = Self.frame(xcodeObserver: xcodeObserver) ?? .zero
    let contentFrame = getUpdatedContentFrame()

    // Convert the coordinate to relative coordinate, where y=0 is the top for SwiftUI.
    containerInfo.parentSize = containerFrame.size
    containerInfo.minX = contentFrame?.minX - containerFrame.minX
    containerInfo.maxX = contentFrame?.maxX - containerFrame.minX
    containerInfo.minY = containerFrame.maxY - contentFrame?.maxY
    containerInfo.maxY = containerFrame.maxY - contentFrame?.minY

    return containerFrame
  }

  static func frame(xcodeObserver: XcodeObserver) -> CGRect? {
    xcodeObserver.state.focusedWorkspace?.axElement.appKitFrame
  }

  static func currentEditor(xcodeObserver: XcodeObserver) -> XcodeEditorState? {
    xcodeObserver.state.focussedEditor
  }

  private var containerInfo = AbsolutePositionInfo()

}

// MARK: - ExpandableViewContainer

private struct ExpandableViewContainer<Content: View>: View {

  init(
    containerInfo: AbsolutePositionInfo,
    content: Content)
  {
    self.content = content
    self.containerInfo = containerInfo
  }

  var body: some View {
    ZStack {
      // The max space the view can take
      HStack {
        if containerInfo.minX == nil {
          Spacer()
        }
        VStack {
          if containerInfo.minY == nil {
            Spacer()
          }
          content
          if containerInfo.maxY == nil {
            Spacer()
          }
        }
        if containerInfo.minX == nil {
          Spacer()
        }
      }
      .frame(width: contentWidth, height: contentHeight)
      .position(x: contentX, y: contentY)
    }
    .frame(width: containerInfo.parentSize.width, height: containerInfo.parentSize.height)
  }

  @State private var containerInfo: AbsolutePositionInfo

  private let content: Content

  private var contentWidth: CGFloat {
    containerInfo.boundedMaxX - containerInfo.boundedMinX
  }

  private var contentHeight: CGFloat {
    containerInfo.boundedMaxY - containerInfo.boundedMinY
  }

  private var contentX: CGFloat {
    containerInfo.boundedMinX + contentWidth / 2
  }

  private var contentY: CGFloat {
    containerInfo.boundedMinY + contentHeight / 2
  }
}

private func -(lhs: CGFloat?, rhs: CGFloat?) -> CGFloat? {
  guard let lhs, let rhs else { return nil }
  return lhs - rhs
}

// MARK: - AbsolutePositionInfo

@Observable
private class AbsolutePositionInfo {

  init(parentSize: CGSize = .zero, minX: CGFloat? = nil, minY: CGFloat? = nil, maxX: CGFloat? = nil, maxY: CGFloat? = nil) {
    self.parentSize = parentSize
    self.minX = minX
    self.minY = minY
    self.maxX = maxX
    self.maxY = maxY
  }

  var parentSize: CGSize
  var minX: CGFloat?
  var minY: CGFloat?
  var maxX: CGFloat?
  var maxY: CGFloat?

  var boundedMinX: CGFloat {
    minX ?? 0
  }

  var boundedMinY: CGFloat {
    minY ?? 0
  }

  var boundedMaxX: CGFloat {
    maxX ?? parentSize.width
  }

  var boundedMaxY: CGFloat {
    maxY ?? parentSize.height
  }
}
