// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation

extension AnyAXUIElement {
  public func getTextFrame(range: NSRange) -> CGRect? {
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
