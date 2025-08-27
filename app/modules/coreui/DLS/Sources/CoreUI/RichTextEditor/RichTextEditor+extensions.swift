// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

extension NSAttributedString {

  func adjustedTextBlockRangeOnSelectionChange(oldRange: NSRange?, newRange: NSRange?) -> NSRange? {
    guard
      let old = oldRange,
      let new = newRange,
      old != new
    else {
      return nil
    }

    let isReverseTraversal = (new.location < old.location) || (new.endLocation < old.endLocation)

    guard new.length > 0 else {
      if
        let textBlockRange = rangeOf(attribute: .textBlock, at: new.location),
        textBlockRange.location != new.location
      {
        let location = isReverseTraversal ? textBlockRange.location : textBlockRange.endLocation
        return NSRange(location: location, length: 0)
      }
      return nil
    }

    let isLocationChanged = new.location != old.location
    let location = isLocationChanged ? new.location : max(0, new.endLocation - 1)

    guard
      let textBlockRange = rangeOf(attribute: .textBlock, at: location),
      textBlockRange.contains(location)
    else {
      return nil
    }

    // return textblock range if new range is entirely contained within textblock range
    if textBlockRange.intersection(new) == new {
      return textBlockRange
    }

    if isReverseTraversal {
      return adjustedTextBlockRangeReverse(new: new, old: old, textBlockRange: textBlockRange)
    } else {
      return adjustedTextBlockRangeForward(new: new, old: old, textBlockRange: textBlockRange)
    }
  }

  /// Returns the range of text that corresponds to a search query, if any, from the current selection.
  /// A search query is triggered by typing `@`. It cannot overlap with a text block nor extend over several lines.f
  /// The returned range contains the initial `@` character.
  func searchRange(from selection: NSRange) -> NSRange? {
    guard selection.length == 0, length > 0 else { return nil }
    let cursorLocation = selection.location

    // First, find the effective range with no textBlock attribute at cursor position
    var effectiveRange = NSRange()
    let hasTextBlockAtCursor = cursorLocation > 0 && attribute(
      .textBlock,
      at: cursorLocation - 1,
      effectiveRange: &effectiveRange) != nil

    if hasTextBlockAtCursor {
      return nil // Cursor is within a text block, don't search
    }

    // Get the substring for the current line to search for '@'
    // Find the beginning of the line (search backward for newline)
    let nsString = string as NSString
    var lineStart = cursorLocation
    let textLength = nsString.length

    // Find start of line (find previous newline or start of text)
    while lineStart > 0 {
      lineStart -= 1
      // Check if attribute changes to a text block (boundary of searchable area)
      if attribute(.textBlock, at: lineStart, effectiveRange: nil) != nil {
        lineStart += 1 // Move past the text block boundary
        break
      }

      if nsString.character(at: lineStart) == Self.newLineChar {
        lineStart += 1 // Move past the newline
        break
      }
    }

    // Find the @ symbol in the portion before cursor
    var searchStartIndex: Int?

    for i in stride(from: cursorLocation - 1, through: lineStart, by: -1) {
      if nsString.character(at: i) == Self.atChar {
        searchStartIndex = i
        break
      }
      if isWhiteSpace(nsString.character(at: i)) {
        break
      }
    }

    guard let searchStartIndex else { return nil }

    // Find the end (until newline, @ or end of effective range)
    var searchEndIndex = max(cursorLocation, searchStartIndex + 1)
    let maxEnd = min(effectiveRange.location + effectiveRange.length, textLength)

    while searchEndIndex < maxEnd {
      let char = nsString.character(at: searchEndIndex)
      if char == Self.atChar || isWhiteSpace(char) {
        break
      }
      searchEndIndex += 1
    }

    return NSRange(location: searchStartIndex, length: searchEndIndex - searchStartIndex)
  }

  private static let newLineChar: unichar = NSString(string: "\n").character(at: 0)
  private static let carriageReturnChar: unichar = NSString(string: "\r").character(at: 0)
  private static let space: unichar = NSString(string: " ").character(at: 0)
  private static let atChar: unichar = NSString(string: "@").character(at: 0)

  private func isWhiteSpace(_ char: unichar) -> Bool {
    char == Self.space || char == Self.carriageReturnChar || char == Self.newLineChar
  }

  private func adjustedTextBlockRangeReverse(new: NSRange, old: NSRange, textBlockRange: NSRange) -> NSRange {
    if
      textBlockRange.union(new) == textBlockRange, new.endLocation == old.endLocation,
      textBlockRange.contains(new.location) == false
    {
      NSRange(location: textBlockRange.location, length: old.endLocation - textBlockRange.endLocation)
    } else if new.endLocation < textBlockRange.endLocation, new.endLocation > textBlockRange.location {
      NSRange(location: new.location, length: textBlockRange.location - new.location)
    } else {
      textBlockRange.union(new)
    }
  }

  private func adjustedTextBlockRangeForward(new: NSRange, old: NSRange, textBlockRange: NSRange) -> NSRange {
    let range: NSRange
    let isLocationChanged = new.location != old.location
    if
      new.contains(textBlockRange.location) && new.contains(textBlockRange.endLocation - 1)
      || (textBlockRange.union(new) == textBlockRange && new.length > 0 && isLocationChanged == false)
      || isLocationChanged == false
    {
      range = new.union(textBlockRange)
    } else {
      range = NSRange(location: textBlockRange.endLocation, length: new.endLocation - textBlockRange.endLocation)
    }
    return range
  }

  /// Gets the next range of attribute starting at the given location in direction based on reverse lookup flag
  /// - Parameters:
  ///   - attribute: Name of the attribute to look up
  ///   - location: Starting location
  ///   - reverseLookup: When true, look up is carried out in reverse direction. Default is false.
  private func rangeOf(
    attribute: NSAttributedString.Key,
    startingLocation location: Int,
    reverseLookup: Bool = false)
    -> NSRange?
  {
    guard
      location >= 0,
      location < length
    else { return nil }

    let range = reverseLookup ? NSRange(location: 0, length: location) : NSRange(location: location, length: length - location)
    let options = reverseLookup ? EnumerationOptions.reverse : []

    var attributeRange: NSRange? = nil
    enumerateAttribute(attribute, in: range, options: options) { val, attrRange, stop in
      if val != nil {
        attributeRange = attrRange
        stop.pointee = true
      }
    }

    return attributeRange
  }

  /// Gets the complete range of attribute at the given location. The attribute is looked up in both forward and
  /// reverse direction and a combined range is returned.  Nil if the attribute does not exist in the given location
  /// - Parameters:
  ///   - attribute: Attribute to search
  ///   - location: Location to inspect
  private func rangeOf(attribute: NSAttributedString.Key, at location: Int) -> NSRange? {
    guard
      location >= 0,
      location < length,
      self.attribute(attribute, at: location, effectiveRange: nil) != nil
    else { return nil }

    var forwardRange = rangeOf(attribute: attribute, startingLocation: location, reverseLookup: false)
    var reverseRange = rangeOf(attribute: attribute, startingLocation: location, reverseLookup: true)

    if forwardRange?.contains(location) == false {
      forwardRange = nil
    }

    if
      let r = reverseRange,
      r.endLocation < location
    {
      reverseRange = nil
    }

    return switch (reverseRange, forwardRange) {
    case (.some(let r), .some(let f)):
      NSRange(location: r.location, length: r.length + f.length)
    case (.none, .some(let f)):
      f
    case (.some(let r), .none):
      r
    default:
      nil
    }
  }

}

extension NSRange {

  var endLocation: Int {
    location + length
  }
}
