// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

extension Collection {
  /// Returns the element at the specified index if it is within bounds, otherwise nil.
  public subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

extension Collection {
  /// Return the next index, or the current one if we are at the end index already.
  public func safeIndex(after i: Index) -> Index {
    if i == endIndex { endIndex }
    else { index(after: i) }
  }

  /// Return the index offset by the offset, or the end index if the offset is out of range.
  public func safeIndex(_ i: Index, offsetBy offset: Int) -> Index {
    var index = i
    for _ in 0..<offset {
      index = safeIndex(after: index)
    }
    return index
  }
}
