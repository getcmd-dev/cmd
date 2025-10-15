// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import Combine
import ConcurrencyFoundation
import DLS
import SwiftUI

// MARK: - AttachmentsView

@MainActor
struct AttachmentsView: View {

  /// Creates a view to display an attachment in the chat input.
  init(
    searchAttachment: ((Bool) -> Void)? = nil,
    attachments: Binding<[AttachmentModel]>,
    isEditable: Bool = true)
  {
    self.searchAttachment = searchAttachment
    _attachments = attachments
    self.isEditable = isEditable
  }

  @Binding var attachments: [AttachmentModel]
  @State var previewedAttachment: AttachmentModel?
  @State var isSearching = false

  var body: some View {
    WrappingHStack(horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing) {
      if isEditable, let searchAttachment {
        RoundedButton(
          cornerRadius: 4,
          action: {
            isSearching.toggle()
            searchAttachment(isSearching)
          }, label: {
            Text("@")
              .font(.system(size: 12, weight: .semibold))
              .frame(width: 14, height: 14)
          })
          .frame(height: 20)
      }
      ForEach(attachments) { attachment in
        AttachmentItemView(
          attachment: attachment,
          removeAttachment: isEditable ? { remove(attachment: $0) } : nil,
          primaryAction: preview(attachment:))
      }
      .frame(height: 20)
    }.onChange(of: attachments) { _, newValue in
      // Remove the preview if the attachment is removed.
      // This will be triggered if `$attachments` is updated from outside this view.
      previewedAttachment = newValue.first { $0 == previewedAttachment }
    }
    if let previewedAttachment {
      AttachmentPreview(attachment: previewedAttachment)
    }
  }

  private let searchAttachment: ((Bool) -> Void)?

  private let isEditable: Bool
  private let horizontalSpacing: CGFloat = 4
  private let verticalSpacing: CGFloat = 7

  private func preview(attachment: AttachmentModel) {
    if previewedAttachment == attachment {
      previewedAttachment = nil
    } else {
      previewedAttachment = attachment
    }
  }

  private func remove(attachment: AttachmentModel) {
    attachments.removeAll { $0 == attachment }
  }
}

#if DEBUG
let imageData: Data = NSImage(systemSymbolName: "car", accessibilityDescription: nil)?
  .tiffRepresentation(using: .jpeg, factor: 1) ?? Data()

#Preview {
  VStack {
    AttachmentsView(attachments: Binding<[AttachmentModel]>.constant([.fileSelection(.init(
      file: .init(path: URL(filePath: "/Users/me/app/source.swift")!, content: mediumFileContent),
      startLine: 12,
      endLine: 34))]))
      .padding()

    AttachmentsView(
      attachments: .constant([
        .fileSelection(.init(
          file: .init(path: URL(filePath: "/Users/me/app/source.swift")!, content: shortFileContent),
          startLine: 12,
          endLine: 34)),
        .image(.init(imageData: imageData, path: nil, mimeType: "image/png")),
      ]))
      .padding()
  }
}
#endif
