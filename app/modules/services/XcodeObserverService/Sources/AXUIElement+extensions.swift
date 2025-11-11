// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation

extension AXUIElement {

  var documentURL: URL? {
    // fetch file path of the frontmost window of Xcode through Accessibility API.
    let path = document
    if let path = path?.removingPercentEncoding {
      let url = URL(
        fileURLWithPath: path
          .replacingOccurrences(of: "file://", with: ""))
      if url.pathExtension == "playground", url.isDirectory {
        return url.appendingPathComponent("Contents.swift")
      }
      return url
    }
    return nil
  }
}

extension URL {
  var isDirectory: Bool {
    (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
  }
}
