// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
@testable import SwiftModule

final class MockFileManager: FileManagerI {
  init(files: [String: String] = [:]) {
    self.files = files
  }

  /// Creates a mock file manager by copying the files from a local repository.
  /// - Parameter repoURL: The URL of the local repository to copy files from.
  /// return: A mock file manager with the files from the repository. The path of the files will be prefixed with "/repo" and otherwise relative to the repoURL.
  init(copyingRepoAt repoURL: URL) {
    guard
      let enumerator = FileManager.default.enumerator(
        at: repoURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: .skipsHiddenFiles)
    else {
      self.files = [:]
      return
    }
    var files = [String: String]()
    for case let fileURL as URL in enumerator {
      let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
      if resourceValues?.isDirectory == true {
        continue
      }
      files[fileURL.standardizedFileURL.path.replacingOccurrences(of: repoURL.standardizedFileURL.path, with: "/repo")] =
        (try? String(contentsOf: fileURL)) ?? ""
    }
    self.files = files
  }

  private(set) var files: [String: String]

  func contentsOfDirectory(at url: URL) throws -> [URL] {
    let content: Set<String> = files.keys
      .map(URL.init(fileURLWithPath:))
      .filter { $0.path.hasPrefix(url.path) && $0.pathComponents.count > url.pathComponents.count }
      .map { file in
        var file = file
        while file.pathComponents.count > url.pathComponents.count + 1 {
          file = file.deletingLastPathComponent()
        }
        return file
      }
      .reduce(into: Set<String>(), { (result: inout Set<String>, url: URL) in
        result.insert(url.path)
      })
    return content
      .map { URL(fileURLWithPath: $0) }
      .sorted(using: KeyPathComparator(\.path))
  }

  func files(
    at baseURL: URL,
    includingPropertiesForKeys _: [URLResourceKey]?,
    options _: FileManager.DirectoryEnumerationOptions)
    -> [URL]?
  {
    files.keys
      .filter { $0.hasPrefix(baseURL.standardizedFileURL.path) }
      .map { URL(fileURLWithPath: $0) }
  }

  func fileExists(atPath: String) -> Bool {
    files.keys.contains { $0 == atPath }
  }

//  func contentsOfFile(contentsOfFile path: String) throws -> String {
//    guard let content = files.first(where: { $0.key == path })?.value else {
//      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
//    }
//    return content
//  }

  func write(_ content: String, to url: URL, atomically _: Bool, encoding _: String.Encoding) throws {
    files[url.standardizedFileURL.path] = content
  }

  func removeItem(atPath: String) throws {
    files.removeValue(forKey: atPath)
  }

  func read(contentsOfFile filePath: String) throws -> String {
    guard let content = files.first(where: { $0.key == filePath })?.value else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
    }
    return content
  }

}
