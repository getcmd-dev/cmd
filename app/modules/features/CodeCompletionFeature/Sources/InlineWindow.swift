// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppKit
import Combine
import Dependencies
import LoggingServiceInterface
import SwiftUI
import XcodeObserverServiceInterface
import XcodeObserverWindowsAdapter

// MARK: - InlineChatPanel

final class InlineChatPanel: ExpandableXcodeWindow<ContentView> {

  init() {
    @Dependency(\.xcodeObserver) var xcodeObserver
    let lineHeight = Self.selectedLineFrame(xcodeObserver: xcodeObserver)?.height ?? 0
    super.init(content: ContentView(lineHeight: lineHeight))
  }

  typealias Dependencies = XcodeObserverProviding

  static func selectedLineFrame(xcodeObserver: XcodeObserver) -> CGRect? {
    guard
      let editor = xcodeObserver.state.focussedEditor,
      let editorFrame = editor.axElement.appKitFrame
    else {
      return nil
    }
    let characterPosition = editor.selections.first?.start.character

    guard
      let selectedLineFrame = UpdateLocationStrategy
        .getSelectionFirstLineFrame(editor: editor.axElement)?
        .invertedFrame
    else {
      return nil
    }
    // If the selection is out of the editor frame, we don't show the panel.
    if selectedLineFrame.maxY < editorFrame.minY || selectedLineFrame.minY > editorFrame.maxY {
      return nil
    }

    return .init(x: editorFrame.minX, y: selectedLineFrame.minY, width: editorFrame.width, height: selectedLineFrame.height)
  }

  override func getUpdatedContentFrame() -> (minX: CGFloat?, maxX: CGFloat?, minY: CGFloat?, maxY: CGFloat?)? {
    guard let frame = Self.selectedLineFrame(xcodeObserver: xcodeObserver) else {
      return nil
    }

    // TODO: deal with scrolling etc
    return (minX: frame.minX, maxX: frame.maxX, minY: frame.maxY, maxY: nil)
  }
}

// MARK: - ContentView

struct ContentView: View {

  let lineHeight: CGFloat

  var body: some View {
    ZStack {
      Rectangle().foregroundColor(.red)
      HStack {
        Button(action: {
          lineCount += 1
        }) {
          Text("+")
        }
        Button(action: {
          lineCount -= 1
        }) {
          Text("-")
        }
      }
    }
    .frame(height: CGFloat(lineCount) * lineHeight + 5)
  }

  @State private var lineCount = 1

}

// MARK: - UpdateLocationStrategy

extension AnyAXUIElement {
  func getTextFrame(range: NSRange) -> CGRect? {
    var r = CFRange(location: range.location, length: range.length)
    guard let rangeValue = AXValueCreate(.cfRange, &r) else { return nil }

    let rectValue: AXValue? = try? wrappedValue?
      .copyParameterizedValue(
        key: kAXBoundsForRangeParameterizedAttribute,
        parameters: rangeValue)
    guard let rectValue else { return nil }

    var rect = CGRect.zero
    let success = AXValueGetValue(rectValue, .cgRect, &rect)
    if success {
      if rect.size != .zero {
        return rect
      } else {
        // When the selected range is out of the scope of the scroll view by some margin, the returned value is not usable.
        // It has a size of 0 so we can discard it.
        // This likely relates to the text view discarding the position of rows that are far out of the scroll view's bound.
        return nil
      }
    } else {
      return nil
    }
  }
}

// MARK: - UpdateLocationStrategy

enum UpdateLocationStrategy {

  static func getTextFrame(startIndex: Int, length: Int, textContainer: AnyAXUIElement) -> CGRect? {
    var r = CFRange(location: startIndex, length: length)
    guard let rangeValue = AXValueCreate(.cfRange, &r) else { return nil }

    let rectValue: AXValue? = try? textContainer.wrappedValue?
      .copyParameterizedValue(
        key: kAXBoundsForRangeParameterizedAttribute,
        parameters: rangeValue)
    guard let rectValue else { return nil }

    var rect = CGRect.zero
    let success = AXValueGetValue(rectValue, .cgRect, &rect)
    if success {
      return rect
    } else {
      return nil
    }
  }

  /// Get the frame of the first line of the selection.
  /// characterOffset: the number of characters before the selection that the frame should start at. For instance the number of characters to the beginning of the line.
  static func getSelectionFirstLineFrame(editor: AnyAXUIElement, characterOffset: Int = 0) -> CGRect? {
    guard let selection = getSelection(editor: editor) else { return nil }
    var (selectedRange, selectionFrame) = selection

    var firstLineRange = CFRange()
    let foundFirstLine = AXValueGetValue(selectedRange, .cfRange, &firstLineRange)
    firstLineRange.length = 0
    firstLineRange.location -= characterOffset

    #warning(
      "FIXME: When selection is too low and out of the screen, the selection range becomes something else.")

    if
      foundFirstLine,
      let firstLineSelectionRange = AXValueCreate(.cfRange, &firstLineRange),
      let firstLineRect: AXValue = try? editor.wrappedValue?.copyParameterizedValue(
        key: kAXBoundsForRangeParameterizedAttribute,
        parameters: firstLineSelectionRange)
    {
      var firstLineFrame = CGRect.zero
      let foundFirstLineFrame = AXValueGetValue(firstLineRect, .cgRect, &firstLineFrame)
      if foundFirstLineFrame {
        selectionFrame = firstLineFrame
      }
    }

    return selectionFrame
  }

  private static func getSelection(editor: AnyAXUIElement) -> (AXValue, CGRect)? {
    guard
      let selectedRange: AXValue = try? editor.wrappedValue?
        .copyValue(key: kAXSelectedTextRangeAttribute),
      let rect: AXValue = try? editor.wrappedValue?.copyParameterizedValue(
        key: kAXBoundsForRangeParameterizedAttribute,
        parameters: selectedRange)
    else {
      return nil
    }
    var selectionFrame = CGRect.zero
    let found = AXValueGetValue(rect, .cgRect, &selectionFrame)
    guard found else {
      return nil
    }

    return (selectedRange, selectionFrame)
  }

}
