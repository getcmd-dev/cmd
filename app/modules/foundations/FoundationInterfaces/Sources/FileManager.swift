// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation

// MARK: - FileManagerI

public protocol FileManagerI: Sendable {
  func urls(
    for directory: FileManager.SearchPathDirectory,
    in domainMask: FileManager.SearchPathDomainMask)
    -> [URL]

  func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool,
    attributes: [FileAttributeKey: Any]?)
    throws
  func createDirectory(
    atPath path: String,
    withIntermediateDirectories createIntermediates: Bool,
    attributes: [FileAttributeKey: Any]?)
    throws
  func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAtPath path: String) throws
  func copyItem(atPath srcPath: String, toPath dstPath: String) throws
  func removeItem(atPath path: String) throws
  func fileExists(atPath path: String) -> Bool
  func contentsOfDirectory(
    at url: URL,
    includingPropertiesForKeys keys: [URLResourceKey]?,
    options mask: FileManager.DirectoryEnumerationOptions)
    throws -> [URL]

  func read(dataFrom url: URL) throws -> Data
  func read(contentsOf url: URL, encoding enc: String.Encoding) throws -> String
  func write(data: Data, to url: URL, options: Data.WritingOptions) throws
  func isDirectory(at path: URL) -> Bool
  /// Observe changes to the content of a specific file.
  ///
  /// - Parameters:
  ///   - url: The URL of the file to observe.
  ///   - onChange: A closure that will be called when the content of the file changes.
  ///     If the file is deleted, the closure will be called with `nil`.
  func observeChangesToContent(of url: URL, onChange: @escaping @Sendable (String?) -> Void) throws
    -> AnyCancellable

  /// Returns a directory enumerator object that can be used to perform a deep enumeration of the directory at the specified URL.
  func enumerator(
    at url: URL,
    includingPropertiesForKeys keys: [URLResourceKey]?,
    options mask: FileManager.DirectoryEnumerationOptions,
    errorHandler handler: ((URL, any Error) -> Bool)?)
    -> FileManager.DirectoryEnumerator?

  /// Returns a file handle for writing to the specified URL.
  func fileHandle(forWritingTo: URL) throws -> FileHandle

  /// The home directory for the current user.
  var homeDirectoryForCurrentUser: URL { get }
}

extension FileManagerI {
  public func read(contentsOf url: URL) throws -> String {
    try read(contentsOf: url, encoding: .utf8)
  }

  public func write(data: Data, to url: URL) throws {
    try write(data: data, to: url, options: [])
  }

  public func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws {
    try createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: nil)
  }

  public func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool) throws {
    try createDirectory(atPath: path, withIntermediateDirectories: createIntermediates, attributes: nil)
  }

  /// Returns a directory enumerator object that can be used to perform a deep enumeration of the directory at the specified URL.
  public func enumerator(
    at url: URL,
    includingPropertiesForKeys keys: [URLResourceKey]?,
    options mask: FileManager.DirectoryEnumerationOptions = [])
    -> FileManager.DirectoryEnumerator?
  {
    enumerator(at: url, includingPropertiesForKeys: keys, options: mask, errorHandler: nil)
  }

  public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]? = nil) throws -> [URL] {
    try contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
  }

  /// Creates any required directories for the given file URL.
  public func createDirectories(requiredForFileAt url: URL) throws {
    let directory = url.deletingLastPathComponent()
    if !fileExists(atPath: directory.path) {
      try createDirectory(at: directory, withIntermediateDirectories: true)
    }
  }
}

// MARK: - FileManager + @retroactive @unchecked Sendable

extension FileManager: @retroactive @unchecked Sendable { }

// MARK: - FileManager + FileManagerI

extension FileManager: FileManagerI {

  public func observeChangesToContent(
    of url: URL,
    onChange: @escaping (String?) -> Void)
    throws -> AnyCancellable
  {
    // Observe changes to the file by observing changes to the parent directory.
    // This is because the available APIs are based on inode tracking, and when Xcode updates a file
    // it replaces the inode with another one, making the tracking to the previous inode obsolete.
    let parent = url.deletingLastPathComponent()
    let fd = open(parent.path, O_EVTONLY)
    guard fd >= 0 else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

    var currentContent = try read(contentsOf: url)

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: [.write, .delete, .rename],
      queue: .main)

    source.setEventHandler { [weak self] in
      guard let self else { return }
      do {
        let newContent = try read(contentsOf: url)
        if newContent != currentContent {
          currentContent = newContent
          onChange(newContent)
        }
      } catch {
        onChange(nil)
      }
    }

    source.setCancelHandler {
      close(fd)
    }

    source.activate()

    return AnyCancellable {
      source.cancel()
    }
  }

  public func read(contentsOf url: URL, encoding enc: String.Encoding) throws -> String {
    try String(contentsOf: url, encoding: enc)
  }

  public func read(dataFrom url: URL) throws -> Data {
    try Data(contentsOf: url)
  }

  public func write(data: Data, to url: URL, options: Data.WritingOptions) throws {
    try data.write(to: url, options: options)
  }

  public func isDirectory(at path: URL) -> Bool {
    do {
      return try (path.resourceValues(forKeys: [URLResourceKey.isDirectoryKey]).isDirectory) ?? false
    } catch {
      return false
    }
  }

  public func fileHandle(forWritingTo file: URL) throws -> FileHandle {
    try FileHandle(forWritingTo: file)
  }

}
