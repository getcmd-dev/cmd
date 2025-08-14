// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

extension AsyncStream<Data> {
  /// Given a stream of Data that represents valid JSON objects, but that might be received over several chunks,
  /// or concatenated within the same chunk, return a stream of Data objects, each representing a valid JSON object.
  public var jsonStream: AsyncStream<Data> {
    let (stream, continuation) = AsyncStream<Data>.makeStream()
    Task {
      var truncatedData = Data()
      for await data in self {
        truncatedData.append(data)
        let (jsonObjects, newTruncatedData) = truncatedData.parseJSONObjects()
        truncatedData = newTruncatedData ?? Data()

        for jsonObject in jsonObjects {
          continuation.yield(jsonObject)
        }
      }
      continuation.finish()
    }
    return stream
  }
}

extension Data {

  /// Given a Data object that represents one or several valid JSON objects concatenated together, with the last one possibly truncated,
  /// return a list of Data objects, each representing a valid JSON object, as well as the optional truncated data.
  func parseJSONObjects() -> (objects: [Data], truncatedData: Data?) {
    var objects = [Data]()
    var isEscaping = false
    var isInString = false

    var openBraceCount = 0
    var currentChunkStartIndex: Int? = 0

    for (idx, byte) in enumerated() {
      if isEscaping {
        isEscaping = false
        continue
      }

      if byte == Self.escape {
        isEscaping = true
        continue
      }

      if byte == Self.quote {
        isInString = !isInString
        continue
      }

      if !isInString {
        if byte == Self.openBrace {
          if openBraceCount == 0 {
            currentChunkStartIndex = idx
          }
          openBraceCount += 1
        } else if byte == Self.closeBrace {
          openBraceCount -= 1

          if openBraceCount == 0, let startIndex = currentChunkStartIndex {
            let object = self[self.startIndex.advanced(by: startIndex) ..< self.startIndex.advanced(by: idx + 1)]
            objects.append(object)
            currentChunkStartIndex = nil
          }
        }
      }
    }

    let truncatedData: Data? =
      if let lastChunkStartIndex = currentChunkStartIndex {
        self[startIndex.advanced(by: lastChunkStartIndex) ..< startIndex.advanced(by: count)]
      } else {
        nil
      }

    return (objects: objects, truncatedData: truncatedData)
  }

  private static let openBrace = UInt8(ascii: "{")
  private static let closeBrace = UInt8(ascii: "}")
  private static let quote = UInt8(ascii: "\"")
  private static let escape = UInt8(ascii: "\\")
}
