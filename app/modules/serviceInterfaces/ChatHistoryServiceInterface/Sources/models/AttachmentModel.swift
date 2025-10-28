// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Attachment

public enum AttachmentModel: Identifiable, Sendable {
  case file(FileAttachmentModel)
  case image(ImageAttachmentModel)
  case fileSelection(FileSelectionAttachmentModel)
  case folder(FolderAttachmentModel)
  case buildError(BuildErrorModel)

  public struct FileAttachmentModel: Identifiable, Sendable {
    public let id: UUID
    public let path: URL
    public let content: String

    public init(id: UUID, path: URL, content: String) {
      self.id = id
      self.path = path
      self.content = content
    }
  }

  public struct ImageAttachmentModel: Identifiable, Sendable {

    public init(id: UUID, imageData: Data, path: URL?, mimeType: String) {
      self.id = id
      self.imageData = imageData
      self.path = path
      self.mimeType = mimeType
    }

    public let id: UUID
    public let imageData: Data
    public let path: URL?
    public let mimeType: String
//    public var inferredMimeType: String {
//      if let path {
//        "image/\(path.pathExtension)"
//      } else {
//        // We only support png here
//        "image/png"
//      }
//    }
  }

  public struct FileSelectionAttachmentModel: Identifiable, Sendable {
    public let id: UUID
    public let file: FileAttachmentModel
    public let startLine: Int
    public let endLine: Int

    public init(id: UUID, file: FileAttachmentModel, startLine: Int, endLine: Int) {
      self.id = id
      self.file = file
      self.startLine = startLine
      self.endLine = endLine
    }
  }

  public struct FolderAttachmentModel: Identifiable, Sendable {
    public init(id: UUID, path: URL, files: [Entry]) {
      self.id = id
      self.path = path
      self.files = files
    }

    public struct Entry: Identifiable, Sendable, Equatable, Codable {
      public let path: String

      public init(path: String) {
        self.path = path
      }

      public var id: String {
        path
      }
    }

    public let id: UUID
    public let path: URL
    public let files: [Entry]

  }

  public struct BuildErrorModel: Identifiable, Sendable {
    public let id: UUID
    public let message: String
    public let filePath: URL
    public let line: Int
    public let column: Int

    public init(
      id: UUID,
      message: String,
      filePath: URL,
      line: Int,
      column: Int)
    {
      self.id = id
      self.message = message
      self.filePath = filePath
      self.line = line
      self.column = column
    }
  }

  public var id: UUID {
    switch self {
    case .file(let attachment): attachment.id
    case .image(let attachment): attachment.id
    case .fileSelection(let attachment): attachment.id
    case .folder(let attachment): attachment.id
    case .buildError(let attachment): attachment.id
    }
  }
}
