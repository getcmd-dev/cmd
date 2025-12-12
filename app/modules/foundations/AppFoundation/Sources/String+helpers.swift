// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

extension String {
  public var utf8Data: Data {
    Data(utf8)
  }
}

// MARK: - String + @retroactive CodingKey

extension String: @retroactive CodingKey {

  public init?(stringValue: String) {
    self = stringValue
  }

  public init?(intValue: Int) {
    self = "\(intValue)"
  }

  public var stringValue: String { self }
  public var intValue: Int? { Int(self) }
}

extension AttributedString {
  public func trimmingCharacters(in characterSet: CharacterSet) -> AttributedString {
    let modifiedString = NSMutableAttributedString(attributedString: NSAttributedString(self))
    modifiedString.trimCharacters(in: characterSet)
    return AttributedString(NSAttributedString(attributedString: modifiedString))
  }
}

extension NSAttributedString {
  public func trimmingCharacters(in characterSet: CharacterSet) -> NSAttributedString {
    let modifiedString = NSMutableAttributedString(attributedString: self)
    modifiedString.trimCharacters(in: characterSet)
    return NSAttributedString(attributedString: modifiedString)
  }
}

extension NSMutableAttributedString {
  public func trimCharacters(in characterSet: CharacterSet) {
    var range = (string as NSString).rangeOfCharacter(from: characterSet)

    // Trim leading characters from character set.
    while range.length != 0, range.location == 0 {
      replaceCharacters(in: range, with: "")
      range = (string as NSString).rangeOfCharacter(from: characterSet)
    }

    // Trim trailing characters from character set.
    range = (string as NSString).rangeOfCharacter(from: characterSet, options: .backwards)
    while range.length != 0, NSMaxRange(range) == length {
      replaceCharacters(in: range, with: "")
      range = (string as NSString).rangeOfCharacter(from: characterSet, options: .backwards)
    }
  }
}
