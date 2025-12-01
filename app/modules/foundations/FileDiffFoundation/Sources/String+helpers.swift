// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffTypesFoundation
import Foundation

extension String {
  public func nsRange(of range: FileDiffTypesFoundation.TextRange) -> NSRange? {
    var position = 0
    var length = 0
    for (idx, line) in splitLines().enumerated() {
      if idx < range.start.line {
        position += line.count
      }
      if idx == range.start.line {
        position += range.start.character
        length -= range.start.character
      }
      if idx >= range.start.line, idx < range.end.line {
        length += line.count
      }
      if idx == range.end.line {
        length += range.end.character
        return NSRange(location: position, length: length)
      }
    }
    return nil
  }

  public func location(of location: FileDiffTypesFoundation.TextRange.TextPosition) -> Int? {
    var position = 0
    for (idx, line) in splitLines().enumerated() {
      if idx < location.line {
        position += line.count
      }
      if idx == location.line {
        position += location.character
        return position
      }
    }
    return nil
  }
}
