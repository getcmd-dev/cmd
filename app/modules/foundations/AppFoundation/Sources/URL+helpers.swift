// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

extension URL {
  /// Given a path, that might be relative to the project root or absolute, resolve it to an absolute path.
  public func resolve(from root: URL) -> URL {
    path.resolvePath(from: root)
  }

  /// Whether a given path is within the project root.
  public func isWithin(root: URL) -> Bool {
    path.starts(with: root.path)
  }

  /// The path relative to the given reference URL.
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

extension String {
  public var asURLWithPath: URL {
    URL(fileURLWithPath: removingPercentEncoding ?? self)
  }

  /// Given a path, that might be relative to the project root or absolute, resolve it to an absolute path.
  public func resolvePath(from base: URL?) -> URL {
    let str = removingPercentEncoding ?? self
    guard let base else {
      return URL(fileURLWithPath: str).standardized
    }
    if hasPrefix("/") {
      return URL(fileURLWithPath: str)
    } else {
      return base.appendingPathComponent(str).standardized
    }
  }

}
