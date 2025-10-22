// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Down
import Foundation
import LoggingServiceInterface
import SwiftUI

extension MarkdownStyle {

  public func markdown(for text: String) -> AttributedString {
    let markDown = Down(markdownString: text)
    do {
      let attributedString = try markDown.toAttributedString(using: self)
      return AttributedString(attributedString.trimmedAttributedString())
    } catch {
      defaultLogger.error("Error parsing markdown", error)

      return AttributedString(text)
    }
  }

}

extension NSAttributedString {

  /// Trims new lines and whitespaces off the beginning and the end of attributed strings
  public func trimmedAttributedString() -> NSAttributedString {
    let nonWhiteSpace = CharacterSet.whitespacesAndNewlines.inverted
    let startRange = string.rangeOfCharacter(from: nonWhiteSpace)
    let endRange = string.rangeOfCharacter(from: nonWhiteSpace, options: .backwards)

    // If no non-whitespace characters found, return original string (it's either empty or all whitespace)
    guard let startLocation = startRange?.lowerBound, let endLocation = endRange?.lowerBound else {
      return NSAttributedString(string: "")
    }

    // Check if there's nothing to trim (already trimmed)
    if startLocation == string.startIndex, endLocation == string.index(before: string.endIndex) {
      return self
    }

    let trimmedRange = startLocation...endLocation
    return attributedSubstring(from: NSRange(trimmedRange, in: string))
  }
}
