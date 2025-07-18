// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import ConcurrencyFoundation
import DLS
import SwiftUI

// MARK: - AttachmentItemView

struct AttachmentItemView: View {

  init(
    attachment: AttachmentModel,
    removeAttachment: ((AttachmentModel) -> Void)? = nil,
    primaryAction: ((AttachmentModel) -> Void)? = nil)
  {
    self.attachment = attachment
    self.removeAttachment = removeAttachment
    self.primaryAction = primaryAction

    if case .image(let imageAttachment) = attachment {
      image = ObservableValue(initial: nil, update: imageAttachment.loadImage)
    } else {
      image = .constant(nil)
    }
  }

  let attachment: AttachmentModel

  var body: some View {
    RoundedButton(
      padding: EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5),
      action: { })
    {
      HStack(spacing: 4) {
        if showRemoveButton {
          removeButton
        }
        Button(action: {
          primaryAction?(attachment)
        }) {
          details
            .background(Color.tappableClearButton)
        }.buttonStyle(.plain)
      }
    }
  }

  @Bindable private var image: ObservableValue<Image?>

  private let primaryAction: ((AttachmentModel) -> Void)?
  private let removeAttachment: ((AttachmentModel) -> Void)?

  @ViewBuilder
  private var details: some View {
    switch attachment {
    case .image:
      HStack {
        (image.value ?? Image(systemName: "photo"))
          .resizable()
          .scaledToFit()
          .frame(width: 15, height: 15)
        Text("Image")
      }

    case .file(let file):
      HStack(spacing: 3) {
        FileIcon(filePath: file.path)
          .frame(width: 12, height: 12)
        Text(file.path.lastPathComponent)
      }

    case .fileSelection(let fileSelection):
      HStack(spacing: 3) {
        FileIcon(filePath: fileSelection.file.path)
          .frame(width: 12, height: 12)
        Text("\(fileSelection.file.path.lastPathComponent) (\(fileSelection.startLine)-\(fileSelection.endLine))")
      }

    case .buildError:
      HStack { }
    }
  }

  private var removeButton: some View {
    Button(action: {
      removeAttachment?(attachment)
    }) {
      Image(systemName: "xmark")
        .font(.system(size: 10, weight: .semibold))
        .tappableTransparentBackground()
    }.buttonStyle(.plain)
  }

  private var showRemoveButton: Bool {
    removeAttachment != nil
  }
}
