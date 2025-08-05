// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FoundationInterfaces

// MARK: - AttachmentSerializer

/// This helper is meant to be attached to a `Decoder` / `Encoder` 's userInfo to allow for file attachments
/// properties to be serialized independently (the main object serializes a reference, and the file attachment is written to a separate file).
final class AttachmentSerializer: Sendable {
  init(fileManager: FileManagerI, objectsDir: URL) {
    self.fileManager = fileManager
    self.objectsDir = objectsDir
  }

  static let attachmentSerializerKey = CodingUserInfoKey(rawValue: "attachmentSerializer")!

//  static let toolsPluginKey = CodingUserInfoKey(rawValue: "toolsPlugin")!

  func save(_ string: String, for id: UUID) throws {
    let data = Data(string.utf8)
    try save(data, for: id)
  }

  func save(_ data: Data, for id: UUID) throws {
    let objectPath = objectsDir.appendingPathComponent("\(id).json")
    try fileManager.createDirectory(
      at: objectsDir,
      withIntermediateDirectories: true,
      attributes: nil)
    return try fileManager.write(data: data, to: objectPath, options: .atomic)
  }

  func read(_: String.Type, for id: UUID) throws -> String {
    let data = try read(Data.self, for: id)
    guard let string = String(data: data, encoding: .utf8) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Failed to decode string from data"))
    }
    return string
  }

  func read(_: Data.Type, for id: UUID) throws -> Data {
    let objectPath = objectsDir.appendingPathComponent("\(id).json")
    return try fileManager.read(dataFrom: objectPath)
  }

  private let fileManager: FileManagerI
  private let objectsDir: URL

}

extension Decoder {
  var attachmentSerializer: AttachmentSerializer {
    get throws {
      guard let loader = userInfo[AttachmentSerializer.attachmentSerializerKey] as? AttachmentSerializer else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "AttachmentSerializer not found in userInfo"))
      }
      return loader
    }
  }
}

extension Encoder {
  var attachmentSerializer: AttachmentSerializer {
    get throws {
      guard let loader = userInfo[AttachmentSerializer.attachmentSerializerKey] as? AttachmentSerializer else {
        throw EncodingError.invalidValue(
          self,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "AttachmentSerializer not found in userInfo"))
      }
      return loader
    }
  }
}
