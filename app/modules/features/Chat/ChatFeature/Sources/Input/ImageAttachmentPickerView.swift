// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import DLS
import SwiftUI

// MARK: - ImageAttachmentPickerView

struct ImageAttachmentPickerView: View {

  var attachments: Binding<[AttachmentModel]>

  var body: some View {
    IconButton(
      action: {
        selectImage()
      },
      systemName: "photo",
      cornerRadius: 0)
      .foregroundColor(.primary)
  }

  private func selectImage() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.image]

    panel.begin { response in
      if response == .OK {
        Task { @MainActor in
          handleSelectedImages(panel.urls)
        }
      }
    }
  }

  private func handleSelectedImages(_ urls: [URL]) {
    // Process selected images
    let newAttachments = urls.compactMap { url -> AttachmentModel? in
      guard let data = try? Data(contentsOf: url) else {
        // TODO: show the error
        return nil
      }

      return AttachmentModel.image(.init(imageData: data, path: url, mimeType: "image/\(url.pathExtension)"))
    }
    var allAttachments = attachments.wrappedValue
    allAttachments.append(contentsOf: newAttachments)
    attachments.wrappedValue = allAttachments
  }
}

#if DEBUG
#Preview {
  ImageAttachmentPickerView(attachments: .constant([]))
}
#endif
