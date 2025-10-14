// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// DI to help with testing

// MARK: - FileManagerI

protocol FileManagerI {
  func files(
    at baseURL: URL,
    includingPropertiesForKeys keys: [URLResourceKey]?,
    options mask: FileManager.DirectoryEnumerationOptions)
    -> [URL]?

  func contentsOfDirectory(at url: URL) throws -> [URL]

  func fileExists(atPath: String) -> Bool

  func write(
    _ content: String,
    to url: URL,
    atomically useAuxiliaryFile: Bool,
    encoding enc: String.Encoding)
    throws

  func read(contentsOfFile filePath: String) throws -> String

  func removeItem(atPath: String) throws
}

extension FileManagerI {
  func files(at baseURL: URL, includingPropertiesForKeys keys: [URLResourceKey]? = nil) -> [URL]? {
    files(at: baseURL, includingPropertiesForKeys: keys, options: [])
  }
}

// MARK: - FileManager + FileManagerI

extension FileManager: FileManagerI {
  func contentsOfDirectory(at url: URL) throws -> [URL] {
    try contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
  }

  func read(contentsOfFile filePath: String) throws -> String {
    try String(contentsOfFile: filePath)
  }

  func files(
    at baseURL: URL,
    includingPropertiesForKeys _: [URLResourceKey]?,
    options _: FileManager.DirectoryEnumerationOptions)
    -> [URL]?
  {
    guard
      let enumerator = enumerator(
        at: baseURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles])
    else { return nil }
    var files = [URL]()
    for case let file as URL in enumerator {
      files.append(file)
    }
    return files
  }

  func write(
    _ content: String,
    to url: URL,
    atomically useAuxiliaryFile: Bool,
    encoding enc: String.Encoding)
    throws
  {
    try content.write(to: url, atomically: useAuxiliaryFile, encoding: enc)
  }
}

nonisolated(unsafe) var fileManager: FileManagerI = FileManager.default
