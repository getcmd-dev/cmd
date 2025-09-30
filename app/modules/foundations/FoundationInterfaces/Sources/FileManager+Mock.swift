// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation
import ThreadSafe

// MARK: - MockFileManager

@ThreadSafe
public final class MockFileManager: FileManagerI {
  public convenience init(files: [String: String] = [:], directories: [String] = []) {
    self.init(
      files: Dictionary(uniqueKeysWithValues: files.map { key, value in (URL(fileURLWithPath: key), value) }),
      directories: directories.map { URL(fileURLWithPath: $0) })
  }

  public convenience init(files: [URL: String], directories: [URL] = []) {
    self.init(files: files.compactMapValues { $0.asData }, directories: directories)
  }

  public init(files: [URL: Data], directories: [URL]) {
    inLock {
      $0.files = files
      $0.directories = directories
    }
  }

  public var homeDirectoryForCurrentUser = URL(fileURLWithPath: "/mock/home")

  public private(set) var files = [URL: Data]()
  public private(set) var directories = [URL]()

  public func isDirectory(at path: URL) -> Bool {
    directories.map(\.standardized.path).contains(path.standardized.path)
  }

  public func observeChangesToContent(
    of _: URL,
    onChange _: @escaping @Sendable (String?) -> Void)
    -> AnyCancellable
  {
    fatalError("not implemented")
  }

  public func read(contentsOf url: URL, encoding _: String.Encoding) throws -> String {
    guard let content = read(url)?.asString else {
      throw NSError(domain: CocoaError.errorDomain, code: CocoaError.fileNoSuchFile.rawValue)
    }
    return content
  }

  public func read(dataFrom url: URL) throws -> Data {
    guard let content = read(url) else {
      throw NSError(domain: CocoaError.errorDomain, code: CocoaError.fileNoSuchFile.rawValue)
    }
    return content
  }

  public func write(data: Data, to url: URL, options _: Data.WritingOptions) throws {
    set(url, to: data)
  }

  public func write(string: String, to url: URL, options _: Data.WritingOptions) throws {
    set(url, to: string.asData)
  }

  public func createDirectory(
    atPath path: String,
    withIntermediateDirectories createIntermediates: Bool,
    attributes: [FileAttributeKey: Any]?)
    throws
  {
    let url = URL(fileURLWithPath: path)
    try createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
  }

  public func urls(
    for directory: FileManager.SearchPathDirectory,
    in _: FileManager.SearchPathDomainMask)
    -> [URL]
  {
    files.keys.filter { $0.hasDirectoryPath == (directory == .documentDirectory) }
  }

  public func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool,
    attributes _: [FileAttributeKey: Any]?)
    throws
  {
    inLock { $0.directories.append(url) }
    if createIntermediates {
      var url = url
      while !url.lastPathComponent.isEmpty {
        url = url.deletingLastPathComponent()
        let filePath = url.path() // URL is not Sendable, so use a String to silence the warning.
        if filePath.starts(with: "/") {
          break
        }
        inLock { $0.directories.append(URL(filePath: filePath)) }
      }
    }
  }

  public func setAttributes(_: [FileAttributeKey: Any], ofItemAtPath _: String) throws {
    // Noop
  }

  public func copyItem(atPath srcPath: String, toPath dstPath: String) throws {
    inLock { $0.files[path(matching: dstPath)] = $0.files[path(matching: srcPath)] }
  }

  public func removeItem(atPath path: String) throws {
    inLock { $0.files[self.path(matching: path)] = nil }
  }

  public func fileExists(atPath path: String) -> Bool {
    files[self.path(matching: path)] != nil
  }

  public func contentsOfDirectory(
    at url: URL,
    includingPropertiesForKeys _: [URLResourceKey]?,
    options _: FileManager.DirectoryEnumerationOptions)
    throws -> [URL]
  {
    let url = url.standardized
    // Check if the URL exists as a directory
    guard isDirectory(at: url) else {
      return []
    }

    return files.keys.filter { $0.path.hasPrefix(url.path) }
  }

  public func enumerator(
    at url: URL,
    includingPropertiesForKeys _: [URLResourceKey]?,
    options: FileManager.DirectoryEnumerationOptions,
    errorHandler _: ((URL, any Error) -> Bool)?)
    -> FileManager.DirectoryEnumerator?
  {
    let url = url.standardized
    // Check if the URL exists as a directory
    guard isDirectory(at: url) else {
      return nil
    }

    // Get all files and directories that are under this URL
    var allPaths = files.keys.filter { fileURL in
      fileURL.path.hasPrefix(url.path)
    }

    // Respect skipsHiddenFiles option
    if options.contains(.skipsHiddenFiles) {
      allPaths = allPaths.filter { fileURL in
        !fileURL.lastPathComponent.hasPrefix(".")
      }
    }

    return MockDirectoryEnumerator(urls: allPaths.sorted { $0.path < $1.path })
  }

  public func fileHandle(forWritingTo _: URL) throws -> FileHandle {
    fatalError("not implemented")
  }

  // We use URL as keys to support file properties.
  // Since URL are reference types, for most functions we need to compare path instead of references. Those helpers help do this.

  private func read(_ path: URL) -> Data? {
    files[self.path(matching: path)]
  }

  private func set(_ path: URL, to content: Data?) {
    files[self.path(matching: path)] = content
  }

  private func path(matching url: URL) -> URL {
    files.keys.first { $0.path == url.path } ?? url
  }

  private func path(matching url: String) -> URL {
    path(matching: URL(fileURLWithPath: url))
  }
}

// MARK: - MockDirectoryEnumerator

private final class MockDirectoryEnumerator: FileManager.DirectoryEnumerator {

  init(urls: [URL]) {
    self.urls = urls
    super.init()
  }

  override func nextObject() -> Any? {
    guard currentIndex < urls.count else {
      return nil
    }
    let url = urls[currentIndex]
    currentIndex += 1
    return url
  }

  override func skipDescendants() {
    // For simplicity, this is a no-op
    // In a more complete implementation, this would skip all descendants of the current item
  }

  private let urls: [URL]
  private var currentIndex = 0

}

extension Data {
  fileprivate var asString: String? {
    String(data: self, encoding: .utf8)
  }
}

extension String {
  fileprivate var asData: Data? {
    data(using: .utf8)
  }
}
