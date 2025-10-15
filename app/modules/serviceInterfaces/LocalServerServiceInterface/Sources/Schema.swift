// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import JSONFoundation

// MARK: - Schema

public enum Schema { }

extension KeyedDecodingContainer {
  /// Sugar syntax for decoding optional values without changing the type to be non optional.
  func decodeIfPresent<T: Decodable>(_ type: T?.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T? {
    if contains(key) {
      return try decode(type, forKey: key)
    }
    return nil
  }
}
