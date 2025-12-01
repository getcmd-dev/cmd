// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
#Preview {
  VStack(alignment: .leading, spacing: 10) {
    AttachmentItemView(
      attachment: .image(.init(imageData: imageData, path: nil, mimeType: "image/png")),
      removeAttachment: { _ in })
    AttachmentItemView(attachment: .file(.init(path: URL(filePath: "/Users/me/app/source.swift")!, content: mediumFileContent)))
    AttachmentItemView(
      attachment: .fileSelection(.init(
        file: .init(path: URL(filePath: "/Users/me/app/source.swift")!, content: mediumFileContent),
        startLine: 1,
        endLine: 10)), removeAttachment: { _ in })
    AttachmentItemView(
      attachment: .buildError(.init(
        message: "Error!",
        filePath: URL(filePath: "/Users/me/app/source.swift")!,
        line: 4,
        column: 3)),
      removeAttachment: { _ in })
  }
  .padding(10)
}
#endif
