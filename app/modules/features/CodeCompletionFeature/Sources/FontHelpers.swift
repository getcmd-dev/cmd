// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppKit
import XcodeObserverServiceInterface

extension NSFont {
  /// Return the size of the font so that it renders the specified content with the specified width.
  static func size(matching lineWidth: CGFloat, for content: String, using fontName: String) -> CGFloat {
    // Binary search for the font size that produces the target width

    let tolerance: CGFloat = 0.001

    // First try rounded sizes
    var highI = 72
    var lowI = 6
    while highI - lowI > 1 {
      let midI = (lowI + highI) / 2
      let testFont = createFont(name: fontName, size: CGFloat(midI))
      let testWidth = testFont.size(for: content).width

      if abs(testWidth - lineWidth) < tolerance {
        return CGFloat(midI)
      } else if testWidth < lineWidth {
        lowI = midI
      } else {
        highI = midI
      }
    }

    // Then try with float sizes
    var low: CGFloat = 6.0
    var high: CGFloat = 72.0
    while high - low > tolerance {
      let mid = (low + high) / 2.0
      let testFont = createFont(name: fontName, size: mid)
      let testWidth = testFont.size(for: content).width

      if abs(testWidth - lineWidth) < tolerance {
        return mid
      } else if testWidth < lineWidth {
        low = mid
      } else {
        high = mid
      }
    }

    return (low + high) / 2.0
  }

  /// Convert Xcode theme font name to NSFont
  static func createFont(name: String, size: CGFloat) -> NSFont {
    var name = name
    if name.hasPrefix("SFMono") {
      // SFMono is not directly accessible.
      name = name.replacingOccurrences(of: "SFMono", with: ".AppleSystemUIFontMonospaced")
    }

    // Try direct lookup first
    if let font = NSFont(name: name, size: size) {
      return font
    }

    // Fallback to monospaced system font
    return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
  }

  func size(for content: String) -> CGSize {
    // Measure the rendered width of the content with this font
    let attributes: [NSAttributedString.Key: Any] = [.font: self]
    let attributedString = NSAttributedString(string: content, attributes: attributes)
    return attributedString.size()
  }

}

extension String {
  /// Return one line in the file and the size this line is rendered at, if possible.
  /// This result can be used to determine the size of the font to use to match that of Xcode.
  /// Parameters:
  ///  - selection: the cursor position in the file. We assume that lines around this possition are currently displayed
  ///  - element: The AX element representing the text editor where the code is rendered.
  func contentToInferFontSize(around selection: CursorRange, in element: AnyAXUIElement) -> (String, CGRect)? {
    // find the range of lines that have a frame (lines outside of the text's scroll view's buffer have no frame)
    let lines = split(separator: "\n", omittingEmptySubsequences: false)
    var lineOffsets = [Int]()
    var position = 0
    for line in lines {
      lineOffsets.append(position)
      position += line.count + 1 // +1 for the \n separator that was removed
    }

    let selectionLine = selection.start.line
    let selectionLineRange = NSRange(location: lineOffsets[selectionLine], length: lines[selectionLine].count)
    guard let selectionFrame = element.getTextFrame(range: selectionLineRange) else {
      // The selection is out of range, not supported
      return nil
    }
    if lines[selectionLine].shouldBeUsedForFontSizeInference {
      // The selected line is a good candidate to infer font size.
      return (String(lines[selectionLine]), selectionFrame)
    }

    var shortElligibleLines = [(Int, CGRect)]()

    // Lines before
    var l = selection.start.line - 1
    while l > 0 {
      let range = NSRange(location: lineOffsets[l], length: lines[l].count)
      if let frame = element.getTextFrame(range: range) {
        if lines[l].shouldBeUsedForFontSizeInference {
          // We parsed a line that has a frame and a valid content, we can return now
          return (String(lines[l]), frame)
        } else if lines[l].canBeUsedForFontSizeInference {
          shortElligibleLines.append((l, frame))
        }
        l -= 1
      } else {
        break
      }
    }
    l = selection.start.line + 1
    while l < lines.count - 1 {
      let range = NSRange(location: lineOffsets[l], length: lines[l].count)
      if let frame = element.getTextFrame(range: range) {
        if lines[l].shouldBeUsedForFontSizeInference {
          // We parsed a line that has a frame and a valid content, we can return now
          return (String(lines[l]), frame)
        } else if lines[l].canBeUsedForFontSizeInference {
          shortElligibleLines.append((l, frame))
        }
        l += 1
      } else {
        break
      }
    }

    return shortElligibleLines.sorted(by: { l1, l2 in
      lines[l1.0].count < lines[l2.0].count
    }).first.map { (String(lines[$0.0]), $0.1) }
  }
}

extension Substring {
  /// Lines that Xcode matches as `xcode.syntax.comment.doc` use a different font & size.
  /// We cannot base our font size inference on them.
  /// This heuristic should help filtering them out.
  fileprivate var canBeUsedForFontSizeInference: Bool {
    !contains("///") && !contains("*")
  }

  fileprivate var shouldBeUsedForFontSizeInference: Bool {
    canBeUsedForFontSizeInference && count > 10
  }
}

extension String {
  func nsRange(of range: CursorRange) -> NSRange? {
    var position = 0
    var length = 0
    for (idx, line) in split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
      if idx < range.start.line {
        position += line.count + 1 // +1 for the \n separator
      }
      if idx == range.start.line {
        position += range.start.character
        length -= range.start.character
      }
      if idx >= range.start.line, idx < range.end.line {
        length += line.count + 1 // +1 for the \n separator
      }
      if idx == range.end.line {
        length += range.end.character
        return NSRange(location: position, length: length)
      }
    }
    return nil
  }
}
