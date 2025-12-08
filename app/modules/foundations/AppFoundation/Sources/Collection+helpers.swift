// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

extension Collection {
  /// Returns the element at the specified index if it is within bounds, otherwise nil.
  public subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

extension BidirectionalCollection {
  /// Return the next index, or the current one if we are at the end index already.
  public func safeIndex(before i: Index) -> Index {
    if i == startIndex { startIndex }
    else { index(before: i) }
  }

  /// Return the next index, or the current one if we are at the end index already.
  public func safeIndex(after i: Index) -> Index {
    if i == endIndex { endIndex }
    else { index(after: i) }
  }

  /// Return the index offset by the offset, or the end index if the offset is out of range.
  public func safeIndex(_ i: Index, offsetBy offset: Int) -> Index {
    var index = i
    if offset < 0 {
      for _ in 0..<(-offset) {
        index = safeIndex(before: index)
      }
    } else {
      for _ in 0..<offset {
        index = safeIndex(after: index)
      }
    }
    return index
  }

  /// Returns the element at the specified index if it is within bounds, otherwise nil.
  public subscript(around index: Index, _: Int = 5) -> Self.SubSequence {
    let range = safeIndex(index, offsetBy: -5)..<safeIndex(index, offsetBy: 5)
    return self[range]
  }
}
