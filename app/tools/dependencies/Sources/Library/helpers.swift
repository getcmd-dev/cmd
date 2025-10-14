// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftSyntax

extension URL {
  public var canonicalURL: URL {
    var path = path.replacingOccurrences(of: "./", with: "")
    if !path.hasSuffix("/") {
      path += "/"
    }
    // Don't use absoluteURL as it resolves against the real filesystem
    // which doesn't work with mock file managers
    return URL(fileURLWithPath: path)
  }

  public func pathRelative(to reference: URL) -> String {
    var commonPathComponentsCount = 0
    for (a, b) in zip(self.pathComponents, reference.pathComponents) {
      if a != b {
        break
      } else {
        commonPathComponentsCount += 1
      }
    }

    let pathComponents = [String](repeating: "..", count: reference.pathComponents.count - commonPathComponentsCount)
      + pathComponents.dropFirst(commonPathComponentsCount)

    return pathComponents.joined(separator: "/")
  }
}

extension Array {

  public func uniqueSorted(by identifier: (Element) -> some Equatable & Comparable) -> [Element] {
    let sorted: [Element?] = sorted { identifier($0) < identifier($1) }
    return zip(sorted, [nil] + sorted)
      .filter { $0.0.map(identifier) != $0.1.map(identifier) }
      .compactMap(\.0)
  }

  mutating func uniqueSort(by identifier: (Element) -> some Equatable & Comparable) {
    self = uniqueSorted(by: identifier)
  }
}

/// Checks if a directory contains at least one file
func directoryIsNotEmpty(_ url: URL) -> Bool {
  guard
    let contents = fileManager.files(
      at: url,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles])
  else {
    return false
  }
  return !contents.isEmpty
}

extension String {
  public var camelCased: String {
    guard !isEmpty else { return "" }
    let parts = components(separatedBy: .alphanumerics.inverted)
    let first = parts.first!.lowercasingFirst
    let rest = parts.dropFirst().map(\.uppercasingFirst)

    return ([first] + rest).joined()
  }

  public func resolve(with base: String) -> String {
    let cleanPath = replacingOccurrences(of: "./", with: "")
    if cleanPath.hasPrefix("/") {
      return cleanPath
    }
    if base.hasSuffix("/") {
      return base + cleanPath
    }
    return base + "/" + cleanPath
  }

  public func update(
    url: URL,
    atomically: Bool = true,
    encoding: String.Encoding = .utf8)
    throws
  {
    if !fileManager.fileExists(atPath: url.path) {
      try fileManager.write(self, to: url, atomically: atomically, encoding: encoding)
      return
    }
    let currentContent = try fileManager.read(contentsOfFile: url.path)
    // Ignore spaces to mitigate differences caused by the linter after the file is written.
    guard currentContent.replacing(/\s/, with: "") != replacing(/\s/, with: "") else {
      return
    }
    try fileManager.write(self, to: url, atomically: atomically, encoding: encoding)
  }

  private var lowercasingFirst: String { prefix(1).lowercased() + dropFirst() }
  private var uppercasingFirst: String { prefix(1).uppercased() + dropFirst() }

}
