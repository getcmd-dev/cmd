// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import ConcurrencyFoundation
import Foundation
import SwiftUI

// MARK: - Attachment

extension AttachmentModel {
  typealias FileAttachment = AttachmentModel.FileAttachmentModel
  typealias ImageAttachment = AttachmentModel.ImageAttachmentModel
  typealias FileSelectionAttachment = AttachmentModel.FileSelectionAttachmentModel
  typealias BuildError = AttachmentModel.BuildErrorModel

  var file: FileAttachment? {
    switch self {
    case .file(let attachment):
      attachment
    default:
      nil
    }
  }

  var image: ImageAttachment? {
    switch self {
    case .image(let attachment):
      attachment
    default:
      nil
    }
  }

  var fileSelection: FileSelectionAttachment? {
    switch self {
    case .fileSelection(let attachment):
      attachment
    default:
      nil
    }
  }
}

// MARK: - AttachmentModel + Equatable

extension AttachmentModel: Equatable {
  /// Executes a cheap comparison between the attachments based on their id.
  /// This is meant to be used in SwiftUI after it has been verified once that no two attachments with the same content have been created.
  /// - Returns: `true` if both attachments have the same id, `false` otherwise
  public static func ==(lhs: AttachmentModel, rhs: AttachmentModel) -> Bool {
    lhs.id == rhs.id
  }

  /// Executes a deep comparison between two attachments.
  /// - Returns: `true` if both attachments describe the same underlying content, `false` otherwise
  static func ===(lhs: AttachmentModel, rhs: AttachmentModel) -> Bool {
    switch (lhs, rhs) {
    case (.file(let lhs), .file(let rhs)):
      lhs.path == rhs.path
    case (.image, .image):
      false // TODO: is this needed?
    case (.fileSelection(let lhs), .fileSelection(let rhs)):
      lhs.file.path == rhs.file.path && lhs.startLine == rhs.startLine && lhs.endLine == rhs.endLine
    case (.buildError(let lhs), .buildError(let rhs)):
      lhs.filePath == rhs.filePath && lhs.line == rhs.line && lhs.column == rhs.column && lhs.message == rhs.message
    default:
      false
    }
  }
}

extension AttachmentModel.FileAttachment {
  init(path: URL, content: String) {
    self.init(id: UUID(), path: path, content: content)
  }
}

extension AttachmentModel.FileSelectionAttachment {
  init(file: AttachmentModel.FileAttachment, startLine: Int, endLine: Int) {
    self.init(id: UUID(), file: file, startLine: startLine, endLine: endLine)
  }
}

extension AttachmentModel.ImageAttachment {
  init(imageData: Data, path: URL?, mimeType: String) {
    self.init(id: UUID(), imageData: imageData, path: path, mimeType: mimeType)
  }

  func loadImage() async -> Image? {
    await Task.detached {
      if #available(macOS 15.2, *) {
        return try? await Image(importing: imageData, contentType: nil)
      } else {
        let nsImage = NSImage(data: imageData) ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil) ?? NSImage()
        return Image(nsImage: nsImage)
      }
    }.value
  }
}

extension AttachmentModel.BuildError {
  init(message: String, filePath: URL, line: Int, column: Int) {
    self.init(id: UUID(), message: message, filePath: filePath, line: line, column: column)
  }
}
