// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import CodePreview
import ConcurrencyFoundation
import Dependencies
import DLS
import FoundationInterfaces
import SwiftUI

// MARK: - Constants

private enum Constants {
  static let codePreviewCornerRadius: CGFloat = 3
  static let codePreviewBorderWidth: CGFloat = 1
  static let imagePreviewHeight: CGFloat = 200
}

// MARK: - AttachmentPreview

struct AttachmentPreview: View {

  init(attachment: AttachmentModel) {
    self.attachment = attachment

    if case .image(let imageAttachment) = attachment {
      image = ObservableValue(initial: nil, update: imageAttachment.loadImage)
    } else {
      image = .constant(nil)
    }
  }

  let attachment: AttachmentModel

  var body: some View {
    switch attachment {
    case .image:
      HStack {
        (image.value ?? Image(systemName: "photo"))
          .resizable()
          .scaledToFit()
          .frame(height: Constants.imagePreviewHeight)
      }

    case .file(let file):
      CodePreview(
        filePath: file.path,
        startLine: nil,
        endLine: nil,
        content: file.content)

    case .fileSelection(let fileSelection):
      CodePreview(
        filePath: fileSelection.file.path,
        startLine: fileSelection.startLine,
        endLine: fileSelection.endLine,
        content: fileSelection.file.content)

    case .buildError(let buildError):
      VStack(alignment: .leading, spacing: 8) {
        Label(buildError.message, systemImage: "exclamationmark.triangle.fill")
          .foregroundColor(.red)

        if let content = try? fileManager.read(contentsOf: buildError.filePath, encoding: .utf8) {
          CodePreview(
            filePath: buildError.filePath,
            startLine: buildError.line,
            endLine: buildError.line,
            content: content)
            .with(
              cornerRadius: Constants.codePreviewCornerRadius,
              borderColor: colorScheme.textAreaBorderColor)
        }
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  @Bindable private var image: ObservableValue<Image?>

  @Dependency(\.fileManager) private var fileManager

}
