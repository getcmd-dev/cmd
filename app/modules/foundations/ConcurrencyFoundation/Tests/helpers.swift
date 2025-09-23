// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftTesting
import Testing

extension AsyncSequence {
  ///  Wait for the stream to yield a specific value.
  func expectToYield(_ expectedValue: Element, timeout _: TimeInterval = 5) -> SwiftTestingUtils.Expectation
    where Element: Equatable & Sendable, AsyncIterator == AsyncStream<Element>.Iterator
  {
    let exp = expectation(description: "The streamed yielded the expected value")
    var iterator = makeAsyncIterator()
    Task {
      while let value = await iterator.next() {
        if value == expectedValue {
          exp.fulfill()
        }
      }
    }
    return exp
  }
}

extension AsyncStream.Iterator: @unchecked @retroactive Sendable where Self.Element: Sendable { }
