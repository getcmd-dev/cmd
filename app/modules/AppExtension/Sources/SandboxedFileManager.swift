// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Foundation
import FoundationInterfaces

final class SandboxedFileManager: FileManagerI {
  var homeDirectoryForCurrentUser: URL {
    defaultLogger.error("Accessing FileManager.homeDirectoryForCurrentUser from sandboxed process")
    return wrapped.homeDirectoryForCurrentUser
  }

  func enumerator(
    at url: URL,
    includingPropertiesForKeys keys: [URLResourceKey]?,
    options mask: FileManager.DirectoryEnumerationOptions,
    errorHandler handler: ((URL, any Error) -> Bool)?)
    -> FileManager.DirectoryEnumerator?
  {
    defaultLogger
      .error("Accessing FileManager.enumerator(at:includingPropertiesForKeys:options:errorHandler:) from sandboxed process")
    return wrapped.enumerator(at: url, includingPropertiesForKeys: keys, options: mask, errorHandler: handler)
  }

  func write(data: Data, to url: URL, options: Data.WritingOptions) throws {
    defaultLogger.error("Accessing FileManager.write(data:to:options:) from sandboxed process")
    try data.write(to: url, options: options)
  }

  func read(contentsOf url: URL, encoding enc: String.Encoding) throws -> String {
    defaultLogger.error("Accessing FileManager.read(contentsOf:encoding:) from sandboxed process")
    return try String(contentsOf: url, encoding: enc)
  }

  func read(dataFrom url: URL) throws -> Data {
    defaultLogger.error("Accessing FileManager.read(dataFrom:) from sandboxed process")
    return try Data(contentsOf: url)
  }

  func contentsOfDirectory(
    at url: URL,
    includingPropertiesForKeys keys: [URLResourceKey]?,
    options mask: FileManager.DirectoryEnumerationOptions)
    throws -> [URL]
  {
    defaultLogger
      .error("Accessing FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:) from sandboxed process")
    return try wrapped.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
  }

  func createDirectory(
    atPath path: String,
    withIntermediateDirectories createIntermediates: Bool,
    attributes: [FileAttributeKey: Any]?)
    throws
  {
    defaultLogger
      .error("Accessing FileManager.createDirectory(atPath:withIntermediateDirectories:attributes:) from sandboxed process")
    try wrapped.createDirectory(atPath: path, withIntermediateDirectories: createIntermediates, attributes: attributes)
  }

  func createDirectory(
    at url: URL,
    withIntermediateDirectories createIntermediates: Bool,
    attributes: [FileAttributeKey: Any]?)
    throws
  {
    defaultLogger
      .error("Accessing FileManager.createDirectory(at:withIntermediateDirectories:attributes:) from sandboxed process")
    try wrapped.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
  }

  func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
    defaultLogger.error("Accessing FileManager.urls(for:in:) from sandboxed process")
    return wrapped.urls(for: directory, in: domainMask)
  }

  func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAtPath path: String) throws {
    defaultLogger.error("Accessing FileManager.setAttributes(_:ofItemAtPath:) from sandboxed process")
    try wrapped.setAttributes(attributes, ofItemAtPath: path)
  }

  func copyItem(atPath srcPath: String, toPath dstPath: String) throws {
    defaultLogger.error("Accessing FileManager.copyItem(atPath:toPath:) from sandboxed process")
    try wrapped.copyItem(atPath: srcPath, toPath: dstPath)
  }

  func removeItem(atPath path: String) throws {
    defaultLogger.error("Accessing FileManager.removeItem(atPath:) from sandboxed process")
    try wrapped.removeItem(atPath: path)
  }

  func fileExists(atPath path: String) -> Bool {
    defaultLogger.error("Accessing FileManager.fileExists(atPath:) from sandboxed process")
    return wrapped.fileExists(atPath: path)
  }

  func isDirectory(at path: URL) -> Bool {
    defaultLogger.error("Accessing FileManager.isDirectory(at:) from sandboxed process")
    return wrapped.isDirectory(at: path)
  }

  func observeChangesToContent(of url: URL, onChange: @escaping @Sendable (String?) -> Void) throws -> AnyCancellable {
    defaultLogger.error("Accessing FileManager.observeChangesToContent(of:onChange:) from sandboxed process")
    return try wrapped.observeChangesToContent(of: url, onChange: onChange)
  }

  func fileHandle(forWritingTo url: URL) throws -> FileHandle {
    defaultLogger.error("Accessing FileManager.fileHandle(forWritingTo:) from sandboxed process")
    return try wrapped.fileHandle(forWritingTo: url)
  }

  private let wrapped = FileManager.default

}
