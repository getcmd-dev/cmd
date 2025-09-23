// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation

extension TextInput.Reference {
  /// The attributed string that represents the string as a reference block.
  var asReferenceBlock: NSAttributedString {
    NSAttributedString(string: display, attributes: [
      .font: NSFontManager.shared.convert(
        NSFont.preferredFont(forTextStyle: .title3, options: [:]),
        toHaveTrait: .boldFontMask),
      .foregroundColor: NSColor.textColor,
      .reference: id,
      .lockedAttributes:
        [
          NSAttributedString.Key.font,
          NSAttributedString.Key.foregroundColor,
          NSAttributedString.Key.reference,
          NSAttributedString.Key.backgroundColor,
        ],
      .textBlock: UUID().uuidString,
    ])
  }
}

extension TextInput {

  init(_ string: NSAttributedString) {
    var newElements: [Element] = []

    string.enumerateAttributes(in: NSRange(location: 0, length: string.length), options: []) { attributes, range, _ in
      let substring = string.attributedSubstring(from: range).string

      if let id = attributes[.reference] as? String {
        // If the custom reference key exists, treat it as a reference
        let reference = Element.reference(Reference(display: substring, id: id))
        newElements.append(reference)
      } else {
        // Otherwise, treat it as plain text
        let text = Element.text(substring)
        newElements.append(text)
      }
    }

    elements = newElements
  }

  var string: NSAttributedString {
    let attributedString = NSMutableAttributedString()
    for element in elements {
      switch element {
      case .text(let text):
        attributedString.append(NSAttributedString(string: text))
      case .reference(let reference):
        attributedString.append(reference.asReferenceBlock)
      }
    }
    return attributedString
  }
}

extension NSAttributedString.Key {
  public static let reference = NSAttributedString.Key("_reference")
}
