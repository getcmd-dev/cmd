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
