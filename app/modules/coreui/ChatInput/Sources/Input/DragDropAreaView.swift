// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import LoggingServiceInterface
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DragDropAreaView

/// An area where different types of items can be dropped.
struct DragDropAreaView: View {
  @State private var isTargeted = false
  let shape: AnyShape
  let handleDrop: (MultiTypeTransferable) -> Bool

  var body: some View {
    dragDropArea
      .onDrop(
        of: [UTType.fileURL.identifier, UTType.image.identifier, UTType.plainText.identifier],
        isTargeted: $isTargeted)
      { providers in
        onDrop(with: providers)
      }
  }

  @ViewBuilder
  private var dragDropArea: some View {
    if isTargeted {
      shape
        .fill(.gray.opacity(0.1))
    } else {
      Color.clear
    }
  }

  private func onDrop(with providers: [NSItemProvider]) -> Bool {
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
          if
            let data = item as? Data,
            let url = URL(dataRepresentation: data, relativeTo: nil)
          {
            Task { @MainActor in
              handleDrop(.file(url))
            }
          } else {
            assertionFailure("unknown file representation")
          }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
          if let error {
            defaultLogger.error(error)
            return
          }

          var resolvedItem: MultiTypeTransferable?
          if let image = item as? NSImage {
            resolvedItem = .image(image)
          } else if let url = item as? URL {
            resolvedItem = .file(url)
          } else if let data = item as? Data, let image = NSImage(data: data) {
            resolvedItem = .image(image)
          } else {
            assertionFailure("unknown image representation")
          }
          if let resolvedItem {
            Task { @MainActor in
              handleDrop(resolvedItem)
            }
          }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
          if let error {
            defaultLogger.error(error)
            return
          }
          if let data = item as? Data {
            // It seems that the data can arrive in utf16
            if
              let text = String(data: data, encoding: .utf8) ??
              String(data: data, encoding: .utf16) ??
              String(data: data, encoding: .utf32)
            {
              Task { @MainActor in
                handleDrop(.text(text))
              }
            }
          } else {
            assertionFailure("unknown text representation")
          }
        }
      } else {
        return false
      }
    }
    return true
  }
}

// MARK: - TransferError

enum TransferError: Error {
  case importFailed
  case exportFailed
}

// MARK: - MultiTypeTransferable

enum MultiTypeTransferable: Transferable, @unchecked Sendable {
  case text(String)
  case image(NSImage)
  case file(URL)

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(contentType: .fileURL) { transferable in
      if case .file(let url) = transferable {
        return SentTransferredFile(url)
      }
      throw TransferError.exportFailed
    } importing: { file in
      .file(file.file)
    }

    FileRepresentation(contentType: .image) { transferable in
      if case .file(let url) = transferable {
        return SentTransferredFile(url)
      }
      throw TransferError.exportFailed
    } importing: { file in
      .file(file.file)
    }

    // String Representation
    DataRepresentation(contentType: .plainText) { transferable in
      if case .text(let text) = transferable {
        return text.utf8Data
      }
      return Data()
    } importing: { data in
      guard let text = String(data: data, encoding: .utf8) else {
        throw TransferError.importFailed
      }
      return .text(text)
    }

    // Image Representation - Only used when not coming from a file
    DataRepresentation(contentType: .image) { transferable in
      if case .image(let image) = transferable {
        return image.tiffRepresentation ?? Data()
      }
      return Data()
    } importing: { data in
      guard let image = NSImage(data: data) else {
        throw TransferError.importFailed
      }
      return .image(image)
    }
  }
}
